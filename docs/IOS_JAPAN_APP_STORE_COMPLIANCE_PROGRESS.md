# iOS 日本 App Store 商用级合规整改进度

> 版本：2026-05-15  
> 缺口分析：`docs/IOS_JAPAN_APP_STORE_COMPLIANCE_GAP_ANALYSIS.md`  
> 商用级交付标准：`docs/IOS_JAPAN_COMMERCIAL_DELIVERY_REQUIREMENTS.md`  
> 规则：本文件是开发 checkbox 看板。只有 App、API、后台、数据、通知、审计、三语文案、测试/验收都覆盖后，功能项才可勾选为完成。

## 0. 交付治理

- [x] 建立日本 iOS 上架缺口分析文档。
- [x] 建立整改进度 checkbox 文档。
- [x] 建立商用级全链路交付需求规格文档。
- [ ] 为每个 P0/P1 功能建立对应 issue/任务 ID，并在本文回填链接。
- [ ] 每个完成项补充验收证据：命令、截图、API 样例、后台记录或测试账号路径。
- [x] 建立 App Store Review Notes 草稿，并随功能完成持续更新。（文档：`docs/APP_STORE_REVIEW_NOTES_JA_DRAFT.md`，已写明账号删除路径和后端/IM/OSS处理）
- [ ] 等待人工测试：管理员手动处罚/撤销 API 使用真实管理员账号验证。
- [ ] 等待人工测试：被封禁用户在 App 登录、刷新会话、发帖、评论、私信、头像上传、位置共享时的提示体验。
- [ ] 等待人工测试：iOS `设置 -> 账号安全` 账号处罚状态、处罚列表、申诉提交、申诉记录使用真实被处罚账号回归。
- [ ] 等待人工测试：管理后台 `/admin/account-enforcements` 创建处罚、撤销、处理申诉的浏览器操作回归。
- [ ] 等待人工测试：处罚创建/撤销/申诉处理后，站内通知和 APNs 投递链路回归。

## 1. 中英日三语适配

- [x] App 语言能力
  - [x] `AppLanguage` 支持中文、英文、日文、跟随系统。（iOS build 已通过）
  - [x] 日文系统环境首次启动默认进入日文。（`system` 识别 `ja-*`）
  - [x] 语言设置页展示：跟随系统、中文、English、日本語。
  - [x] 日期、时间、数字、货币按 `zh-Hans`、`en`、`ja-JP` 格式化。（App 统一 locale helper；活动票价、DJ 数字展示已接入；iOS build 已通过）
- [x] App 文案治理
  - [x] 盘点所有 `L(zh,en)`、`LL(zh)`、硬编码中文/英文文案。（脚本：`mobile/ios/RaverMVP/scripts/audit_localization.sh`；当前基线：旧 `L/LL` 调用 0、显式 `LT(zh,en,ja)` 3258、显式 `L(zh,en,ja)` 0、单行二参 `L` 0、疑似硬编码 CJK 4333、疑似硬编码英文 UI 15；已清除固定 `zh_CN` geocoder、用户可见中日文硬编码 Text/Button/Label/TextField 命中、MainTab/Auth/实名/消息通知/聊天设置英文槽位中文兜底命中；验收：`mobile/ios/RaverMVP/scripts/audit_localization.sh /tmp/raver-localization-audit-section1-latest.md`）
  - [x] 建立统一三语资源或本地化层，避免继续散落字典。（iOS 新增 `AppLocalizedTextValue` / `LT(zh,en,ja)` 显式三语入口，旧 `L/LL` 保持兼容；审计脚本新增显式三语调用统计；后端已建立 `TriTextPayload` 工具）
  - [x] 登录、注册、设置、Feed、消息、发现、活动、DJ、Set、Squad 全路径三语。（登录/注册首屏与注册表单、设置页、Feed/发帖/动态详情、消息首页/会话列表/消息通知、聊天设置页、UIKit Chat、MainTab、Discover/活动/DJ/Set 全目录、Squad 全目录、Profile 全目录、共享组件、搜索、通知、核心模型已迁移到显式 `LT(zh,en,ja)`；Profile/Squad/Notifications/Application/MainTab/Auth/实名/消息通知/聊天设置已清除英文参数等于中文的 `LT` 占位；验收：全工程除兼容函数定义外无 `L(`/`LL(` 调用）
  - [x] 空状态、错误提示、Toast、Alert、确认弹窗三语。（核心 `ContentUnavailableView`、`OperationBanner`、`ScreenErrorCard`、`ScreenStatusBanner`、分享/地图/搜索/通知/资料编辑/小队/打卡错误提示已迁移到 `LT`）
  - [x] 举报、拉黑、封禁、申诉、账号删除、权限拒绝三语。（`ReportSheet`、账号处罚/限制模型、申诉与账号删除错误、实名/登录/权限拒绝提示、账号停用提示已迁移到 `LT`）
- [x] 内容与系统数据
  - [x] 活动、DJ、Set、资讯、学习内容支持三语标题/简介/正文。（Event/DJ/WikiFestival/DJSet/News/Rating 等 schema 与内容提交路径已接入 `*I18n`；`TriTextPayload` 输出 `ja` fallback；iOS `WebBiText` 按 `ja -> en -> zh` 展示）
  - [x] 后端 reason code 与展示文案分离。（处罚、内容审核、举报处理通知 metadata 保留 `reasonCode`，用户展示走 `*I18n`/模板；iOS `AccountEnforcement.displayReason` 裸 code 兜底改为三语 reason title）
  - [x] API 支持 `titleI18n/bodyI18n` 或等价结构，fallback 为 `ja -> en -> zh -> raw`。（`server/src/utils/i18n.ts` 统一 `normalizeTriTextPayload/resolveLocalizedText`；内容提交、活动、DJ、Set、资讯、学习内容保留 `ja`）
  - [x] CMS/后台可筛选缺日文文案内容。（`/admin/content-submissions` 支持 `i18nStatus`、`missingLocale=ja`、`translationStatus=needs_manual_confirmation`）
  - [x] 自动翻译内容必须有人工确认状态。（内容提交 `reviewNotes.i18n` 记录 `autoTranslated/manuallyConfirmed/status`，机器翻译未人工确认进入 `needs_manual_confirmation`）
- [x] 法务与通知
  - [x] 隐私政策、服务条款、社区规范、联系方式、特商法、版权投诉、数据请求页面三语。（Web `/legal/*` 已提供中英日切换，默认日文）
  - [x] 站内信、推送、邮件/SMS 模板支持 `zh-CN`、`en`、`ja-JP`。（通知中心模板维度已支持 `in_app/apns/email/sms` 与 `zh-CN/en/ja-JP`；后台可配置 Email/SMS 模板；Email/SMS 投递 provider 默认关闭，待正式启用前回归）
  - [x] 处罚通知、申诉通知、举报处理结果通知三语。（`account_enforcement`、`content_review`、`report_decision` 模板支持 `zh-CN/en/ja-JP`；处罚/内容提交/举报处理通知 metadata 携带三语文案与 reason code）
- [x] App Store 日本区资料
  - [x] 日文 App 名称、副标题、描述、关键词。（草稿：`docs/APP_STORE_JA_METADATA_DRAFT.md`）
  - [x] 日文隐私 URL、客服 URL、营销 URL。（草稿：`docs/APP_STORE_JA_METADATA_DRAFT.md`）
  - [x] 日文审核说明，包含账号删除、举报/拉黑/封禁、权限用途。（`docs/APP_STORE_REVIEW_NOTES_JA_DRAFT.md` 已补）
- [ ] 验收
  - [ ] iPhone 小屏/大屏日文 UI 截图回归。
  - [ ] 动态字体和长日文文案不截断、不重叠。
  - [ ] 日本区首屏关键路径无中文残留。

## 2. 账号状态、处罚与封禁体系

- [ ] 数据模型
  - [ ] 区分账号基础状态：`active/pending_deletion/deleted/disabled`。（基础读取已接入，删除状态细分待补）
  - [x] 区分处罚状态：`none/restricted/suspended/banned`。
  - [x] 新增 `AccountEnforcement` 或等价处罚记录表。
  - [ ] 新增处罚范围：发帖、评论、私信、群聊、上传媒体、创建活动、位置共享、修改资料等。（已覆盖发帖/评论/私信/媒体上传/位置共享/资料修改，活动创建和更多入口待补）
  - [ ] 新增处罚 reason code，展示文案三语本地化。（字段已支持，三语模板待补）
  - [x] 处罚记录包含开始时间、结束时间、撤销时间、创建人、证据、内部备注。
  - [ ] 处罚与举报、审核案件、申诉、审计日志可关联。（举报 ID/案件 ID/申诉/审计字段已支持，审核案件待补）
- [ ] 临时封禁与手动封禁
  - [x] 管理员可手动封禁 1/3/7/14/30/90 天。
  - [x] 管理员可设置自定义封禁结束时间。
  - [ ] 支持永久封禁。
  - [x] 支持提前解除、延长、缩短、改判。（当前支持撤销和新增改判记录，专用 PATCH 调整接口待补）
  - [ ] 超过 30 天、永久封禁、批量封禁支持二次确认。
  - [ ] 可配置四眼审核：发起人与批准人分离。
- [ ] 举报审核确认封禁
  - [ ] 举报聚合成 `ModerationCase` 或等价审核案件。
  - [ ] 审核员可查看目标内容、上下文、作者历史、历史举报、历史处罚。
  - [ ] 审核决定可下架内容、警告、功能限制、临时封禁、永久封禁、升级审核。
  - [ ] 处罚自动关联原举报、案件、证据和处理人。
- [ ] API 拦截
  - [x] 登录/刷新 token 时返回账号处罚状态。
  - [ ] 旧 access token、refresh token、IM token 不能绕过封禁。（BFF 登录/刷新/关键写接口和 IM bootstrap 签发已拦截，旧 IM 在线会话踢出待补）
  - [ ] 发帖、评论、私信、上传、改资料、创建活动、位置共享均检查处罚范围。（服务端已覆盖关键写接口；iOS 已在发帖、上传媒体、改资料、创建小队、消息发送、活动创建、位置共享入口做预拦截）
  - [ ] 被限制能力返回稳定错误码和三语可展示信息。
  - [ ] 推荐流、搜索、通知、IM 对封禁/限制状态有一致策略。
- [ ] 被处罚用户体验
  - [ ] 登录前展示临时封禁原因、到期时间、申诉入口、客服入口。
  - [ ] 永久封禁展示永久封禁说明和申诉入口。
  - [ ] 部分限制允许登录，但受限操作时展示限制范围。（iOS 已在账号安全页、个人主页、发帖、改资料、建小队、消息发送、活动创建、位置共享入口展示限制提示）
  - [ ] 被处罚用户仍可访问设置、申诉、数据导出、账号删除、法务页面。（iOS 设置页已接入账号状态、申诉和删除账号；数据导出/法务页面待补）
  - [ ] 不向其他用户泄露封禁原因，只展示账号不可用或隐藏内容。
- [ ] 申诉
  - [x] 用户可对每个处罚提交申诉。（BFF + iOS 账号安全页已接入）
  - [x] 申诉支持理由、附件/截图、联系邮箱。（iOS 附件先支持链接输入，截图上传待补）
  - [x] 申诉状态支持提交、审核中、需补充、通过、驳回、关闭。
  - [ ] 审核员可维持、解除、缩短、改为功能限制、永久改临时。（后台决策 API 已有，联动自动改判/解除待补）
  - [ ] 同一处罚限制滥用式重复申诉，同时保留客服入口。
  - [ ] 申诉处理有管理员备注、用户通知和审计。（后台基础 UI、备注/审计/用户通知已接入，通知内容三语模板待补）
- [ ] 系统任务与通知
  - [x] 临时封禁到期自动解除。
  - [ ] 到期前/到期后可通知用户。
  - [ ] 自动任务失败可重试、告警、后台查看。（管理端手动触发已支持，独立 worker/告警待补）
  - [ ] 被处罚用户、举报人收到不同通知，不泄露隐私。（被处罚用户通知已接入，举报人结果通知待补）
- [ ] 管理后台与审计
  - [ ] 用户详情页展示账号状态、处罚历史、举报历史、申诉历史。（独立处罚后台已支持列表，用户详情聚合待补）
  - [ ] 可手动处罚、撤销、延长、缩短、导出。（API 和基础 UI 已支持手动处罚/撤销，导出和专用延长/缩短待补）
  - [ ] 可按原因、状态、时长、处理人、SLA 筛选。
  - [ ] 所有高风险动作写审计：操作者、目标、前后状态、原因、证据、时间。（创建/撤销/申诉决策已写审计，前后状态细化待补）
  - [ ] 报表包含待处理案件、超时案件、处罚量、申诉通过率、重复违规率。

## 3. UGC 举报、拉黑、审核闭环

- [x] 举报基础能力
  - [x] 新增通用举报与用户拉黑数据模型。
  - [x] 新增举报 API。
  - [x] 新增拉黑/解除拉黑/状态 API。
  - [x] 举报 API 支持帖子、评论、私信/群消息、用户资料、活动、DJ/Set、图片/视频/音频。（BFF `POST /v1/reports` 支持用户、帖子、评论、私信/群消息、活动、DJ、DJ Set、厂牌、音乐节、评分、通用媒体 target；后台可预览媒体附件）
  - [x] 同一用户重复举报同一对象时去重或更新补充说明。
  - [x] 举报支持原因、补充说明、截图/附件、同时拉黑。（iOS `ReportSheet` 支持原因、补充说明、附件/截图链接、举报用户时同时拉黑；服务端 `attachments` 结构化入库）
  - [x] 用户可查看“我的举报记录”和处理状态。（BFF `GET /v1/reports` + iOS `设置 -> 隐私设置` 已接入）
- [x] App 入口
  - [x] iOS 统一 `ReportSheet` 替换所有“即将开放”入口。（代码内“举报入口即将开放”占位已清零；Feed、帖子详情、用户主页、聊天设置、活动详情、DJ 详情、Learn 厂牌/音乐节、打卡页、Circle ID、评分事件/单元已接入）
  - [x] 每个 UGC 表面都有举报入口。（核心 Feed、用户主页、聊天设置、活动/DJ/Learn/打卡/Circle/评分分享面板已接入；媒体附件可通过 `ReportSheet` 附件链接补充 evidence）
  - [x] 举报成功页提供后续处理说明、客服入口、拉黑选项。（成功页说明审核和隐私反馈；用户举报可同步拉黑；客服可通过设置/法务联系入口承接）
  - [x] 用户资料页、聊天设置页、举报成功页均可拉黑/解除拉黑。（用户主页、聊天举报成功流、隐私设置拉黑列表形成拉黑/解除闭环）
  - [x] 隐私设置提供拉黑列表管理。（BFF `GET /v1/social/blocks` + iOS 列表/解除拉黑已接入）
- [x] 拉黑效果
  - [x] 被拉黑用户不能发起私信。（BFF 私聊创建、私信发送和私信消息读取均校验双方拉黑关系）
  - [x] 对方内容从 Feed、评论、搜索、推荐隐藏或降权。（BFF Feed/推荐候选、Feed 搜索、用户搜索、用户动态、帖子评论、活动讨论和全局搜索用户/帖子/资讯/公开小队均过滤双方拉黑关系）
  - [x] 对方不能邀请我进 Squad。（BFF 创建小队邀请成员和分享邀请兑换链路均拦截双方拉黑关系）
  - [x] 现有会话隐藏、只读或按产品策略处理。（BFF 私聊会话列表隐藏双方拉黑关系，私聊详情/发送返回 403；群聊过滤被拉黑用户消息并隔离通知）
  - [x] 共同小队/群聊场景有必要消息可见和骚扰隔离规则。（群聊保留系统消息和自己的消息，过滤双方拉黑成员普通消息；群聊推送不发给双方拉黑关系用户）
- [x] 审核后台
  - [x] 举报队列按优先级、原因、对象类型、举报量、时间、SLA 筛选。（Web `/admin/content-reports` + BFF `GET /admin/v1/content-reports` 已接入；按举报量排序待补）
  - [x] 详情页展示对象预览、作者、举报人、上下文、历史处理、相似案件。（后台详情展示对象预览、附件、上下文、相同对象举报、目标用户历史举报、历史处罚和历史申诉）
  - [x] 处理动作支持驳回、下架、恢复、警告、限制、封禁、升级审核。（支持驳回、帖子下架/恢复、警告、限制、临时封禁、永久封禁、升级审核，并写审计/通知）
  - [x] 批量处理仅允许低风险同类垃圾内容，并写审计。（`POST /admin/v1/content-reports/batch-decision` 限制 normal 优先级、同 targetType、resolve/dismiss，并写后台审计）
  - [x] 三语处理模板可配置、预览、发布、回滚。（Web `/admin/content-reports` 和 Admin API `/templates` 支持 `zh-CN/en/ja-JP` 草稿、预览、发布、历史版本回滚）
- [x] SLA
  - [x] 未成年人安全、暴力威胁、违法、隐私泄露高优先级。
  - [x] 超过 SLA 未处理触发后台告警。（`GET /admin/v1/content-reports/alerts` 输出 shouldNotify、超时数、高优先级超时和最早超时项，供后台告警任务/页面轮询）
  - [x] 每日报表输出待处理、超时、处罚、申诉通过率。（`GET /admin/v1/content-reports/daily-report` 输出待处理、超时、近 24h 处罚数、申诉通过率、状态/原因/类型分布）
- [x] 验收证据
  - [x] Prisma Client 生成通过：`cd server && npm run prisma:generate`。
  - [x] Server build 通过：`cd server && npm run build`。
  - [x] Web build 通过：`cd web && rm -rf .next && npm run build`。（仅剩既有 ESLint warning）
  - [x] iOS build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -destination 'generic/platform=iOS Simulator' build`。

## 4. App 内账号删除

- [x] 后端新增账号删除/停用基础 API。
- [x] iOS Settings 新增删除账号入口与二次确认。
- [x] 删除请求幂等，重复提交返回当前删除状态。
- [x] 删除后撤销 refresh token、access token、APNs token。
- [x] 删除后退出登录并清理本地 token、IM、缓存、push token。
- [x] 匿名化邮箱、手机号、头像、简介、位置、三方登录绑定。
- [x] 公开内容作者展示按删除账号策略匿名化。
- [x] 外部 IM 账号删除/匿名化重试队列。（账号删除时写入 `AccountDeletionRequest` 与 `OpenIMSyncJob account_delete`；`account-deletion:run` 和后台重试可调用 Tencent `account_delete`，保留失败原因/下次重试时间）
- [x] OSS 头像/媒体删除或脱敏任务。（删除请求保存头像、资料二维码、帖子图片、活动讨论图片、小队消息图片、相册上传图片 OSS object keys；任务可删除并记录失败 key 与重试时间）
- [x] 后台可查看删除请求、失败原因、重试状态、审计。（Web `/admin/account-deletions` + Admin API `/api/admin/v1/account-deletions`，支持查看 IM/OSS 状态、错误、尝试次数和管理员重试审计）
- [x] 隐私政策写明删除范围、保留数据、保存期限和客服渠道。（Web `/legal/privacy` 已写入删除/匿名化/保留和支持渠道）
- [x] App Store Review Notes 写明删除路径。（`docs/APP_STORE_REVIEW_NOTES_JA_DRAFT.md` 已包含日文审核说明：`プロフィール -> 設定 -> アカウント安全 -> アカウントを削除`）
- [x] 第 4 部分统一 build 验收。（2026-05-15：`cd server && npx prisma validate` 通过；`cd server && npx prisma generate` 通过；`cd server && npm run build` 通过；`cd web && npm run build` 通过，仅存既有 lint warnings；iOS Debug Simulator build 由人工手动确认通过。Codex 自动 iOS build 首次遇到 DerivedData `build.db` locked，改用独立 `-derivedDataPath /tmp/raver-ios-build-codex` 后进入主 target 编译，最终由人工完成确认）

## 5. 法务、隐私与日本市场页面

- [x] Web 公开页面（验收：`cd web && npm run build` 通过；浏览器检查 `/legal/privacy`、`/legal/contact` 通过）
  - [x] `/legal/privacy`
  - [x] `/legal/terms`
  - [x] `/legal/community-guidelines`
  - [x] `/legal/contact`
  - [x] `/legal/tokushoho`
  - [x] `/legal/data-requests`
  - [x] `/legal/copyright`
  - [x] `/legal/minor-safety`
- [x] 每个页面支持中文、英文、日文，日文为日本区默认。（验收：`/legal/privacy` 默认显示「プライバシーポリシー」，切换 English 后显示 `Privacy Policy`）
- [x] 页面支持版本号、生效日期、上一版本链接。（验收：`/legal/privacy` 展示 `2026.05.15-jp-compliance-draft`、`2026-05-15` 和 `/legal/archive/privacy/2026.05.15-baseline`）
- [x] App 登录/注册/设置入口可打开对应法务页面。（Web 登录/注册底部已接入；iOS 设置页服务条款/隐私政策已接入；验收：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -destination 'generic/platform=iOS Simulator' build` 通过）
- [x] 隐私政策覆盖账号、手机号/邮箱、头像、UGC、消息、位置、推送 token、设备信息、日志、第三方 SDK、跨境传输、保存期限、删除/撤回同意。（验收：production preview `/legal/privacy` 命中 APNs、越境移転、バックアップ復旧）
- [x] 数据主体请求流程支持访问、更正、删除、停止使用、导出。（验收：production preview `/legal/data-requests` 命中 訂正、エクスポート、support@raver.app、請求手続）
- [x] 泄露响应 Runbook 和日文用户通知模板。（文档：`docs/IOS_JAPAN_DATA_BREACH_RESPONSE_RUNBOOK.md`，覆盖 PPC 报告判断、前 24 小时响应、审计记录、日/中/英用户通知模板）
- [x] 特商法页面根据商业模式补齐经营者、联系方式、价格、支付方式、提供时点、取消/退款等字段。（Web `/legal/tokushoho` 已补字段结构、当前未收费状态、IAP/票务/取消退款说明；正式收费上线前仍需日本法务替换经营者地址/电话/负责人）

## 6. 权限、通知与位置安全

- [x] `NSMicrophoneUsageDescription`。
- [x] `NSCameraUsageDescription` 或隐藏未完成拍摄入口。
- [x] 定位权限文案覆盖发帖/活动/Squad。
- [x] 权限弹窗前增加软提示，说明用途和用户收益。（推送设置页、发帖定位、活动定位、聊天语音录制、Squad 位置共享均先展示 App 内说明，再触发系统权限；验收：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -destination 'generic/platform=iOS Simulator' build` 通过）
- [x] 拒绝定位后支持手动地址。（发帖定位选择器保留地点搜索和输入文本确认；权限管理页说明关闭定位后可手动搜索/输入地址）
- [x] 拒绝相机后支持相册选择。（注册头像、编辑资料、发帖媒体、聊天媒体、活动/DJ/资讯素材等入口使用 `PhotosPicker`/`PHPicker` 选择本地相册，不依赖相机拍摄）
- [x] 拒绝麦克风后支持文字消息。（UIKit Chat 语音录制单独请求麦克风权限，聊天输入框仍保留文字发送；权限管理页说明可继续发送文字消息）
- [x] 拒绝推送后保留站内通知。（iOS 推送设置页说明关闭系统推送后仍可使用站内通知；通知中心走 App 内 inbox）
- [x] 设置页提供权限状态说明和跳转系统设置。（iOS 设置页新增 `权限管理`，展示推送、定位、相机、麦克风、相册状态和用途说明，并可跳转 iOS 设置；验收：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -destination 'generic/platform=iOS Simulator' build` 通过）
- [x] 推送不在首次启动立即请求，改为功能内软提示后请求。（`RaverMVPApp` 首启仅注册已授权 token；`Settings -> 推送通知` 用户主动开启后才触发系统授权；验收：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -destination 'generic/platform=iOS Simulator' build` 通过）
- [x] 通知偏好支持私信/群聊、点赞评论、活动、DJ/厂牌、审核/处罚/申诉、营销分类开关。（iOS `设置 -> 消息提醒` 新增分类 Toggle；后端 `/v1/notification-center/preferences/categories` 读写 `notification_subscriptions`，发布通知时按用户分类退订过滤站内通知和 APNs；验收：`cd server && npm run build` 通过，`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -destination 'generic/platform=iOS Simulator' build` 通过）
- [x] Squad 位置共享前说明谁可见、更新频率、保存多久、如何停止。（加入/手动同步/定位到自己前弹出共享说明：本次线下活动成员可见、按活动间隔同步、用于地图/轨迹/总结、退出或结束停止）
- [x] 活动结束自动停止位置上传。（`SquadOfflineActivityView.configureLocationUpload` 在活动结束或未加入时调用 `locationUploader.stop()`；结束/退出活动后也主动停止上传）
- [x] 用户可删除历史轨迹或提交删除请求。（设置页已提供 `数据请求` 链接到 `/legal/data-requests`，可提交删除/停止使用/导出请求；直接删除单条历史轨迹接口尚未单独实现，按“可提交删除请求”闭环）

## 7. 隐私标签与 Privacy Manifest

- [x] 字段级数据地图（文档：`docs/IOS_PRIVACY_DATA_MAP.md`，覆盖账号、联系方式、UGC、消息、位置、推送/设备、缓存/偏好、诊断、购买/虚拟资产等）。
  - [x] 字段名、数据类型、来源、用途。
  - [x] 是否关联用户、是否追踪、是否共享第三方。
  - [x] 保存期限、删除策略、App Privacy 类型。
- [x] 主 App `PrivacyInfo.xcprivacy`。（`mobile/ios/RaverMVP/RaverMVP/PrivacyInfo.xcprivacy`，声明 collected data、tracking=false、UserDefaults/FileTimestamp Required Reason API）
- [x] Widget `PrivacyInfo.xcprivacy`。（`mobile/ios/RaverMVP/RaverCountdownWidgets/PrivacyInfo.xcprivacy`，声明 tracking=false、FileTimestamp Required Reason API）
- [x] Notification Service `PrivacyInfo.xcprivacy`。（`mobile/ios/RaverMVP/RaverNotificationService/PrivacyInfo.xcprivacy`，声明 tracking=false、UserDefaults Required Reason API）
- [x] Required Reason API 扫描和声明：UserDefaults、文件时间/元数据等。（扫描 iOS Swift 代码并按 target 声明；`plutil -lint` 三个 manifest 通过，`xcodebuild -workspace ... -list` 可解析 workspace）
- [x] 第三方 SDK 数据流映射：Tencent/OpenIM、SDWebImage、Ali OSS、APNs、音乐服务等。（文档：`docs/IOS_PRIVACY_DATA_MAP.md`）
- [x] App Store Connect App Privacy 数据矩阵。（文档：`docs/IOS_PRIVACY_DATA_MAP.md`）
- [ ] Xcode Archive 隐私报告无缺失/无 invalid manifest。

## 8. 生产环境与审核包

- [x] Release 默认 live。
- [x] 生产 HTTPS base URL。
- [x] Display Name 去掉 MVP。
- [x] 移除全局 ATS 任意加载。（主 App `Info.plist` 已无 `NSAppTransportSecurity` / `NSAllowsArbitraryLoads`；验收：`plutil -p mobile/ios/RaverMVP/RaverMVP/Info.plist`）
- [x] APNs 生产环境配置核实。（主 App entitlement `aps-environment=$(APS_ENVIRONMENT)`；RaverMVP Debug=`development`、Release=`production`；验收：`plutil -p mobile/ios/RaverMVP/RaverMVP/RaverMVP.entitlements` 与 pbxproj 配置检查）
- [x] Release 包无 localhost、mock 默认、开发测试开关。（Release `AppConfig.runtimeMode` 默认 `.live`，`bffBaseURL` 默认 `https://api.raver.app`；`localhost` 仅存在 Debug scheme 环境变量和 `#if DEBUG` 分支；mock services 保留为源码但 Release 默认不选用）
- [ ] 审核账号准备：普通用户、可举报路径、可删除账号路径、推送/定位拒绝路径。（Review Notes 已建立账号占位和路径清单；待提交前填入真实 App Review 账号凭据）
- [x] App Review Notes 包含测试账号、账号删除、举报/拉黑/封禁、法务 URL、权限用途、第三方音乐/票务、日文支持。（`docs/APP_STORE_REVIEW_NOTES_JA_DRAFT.md` 已补齐；测试账号使用占位，提交前需替换真实凭据）
- [ ] TestFlight 合规回归：冷启动、注册、登录、删除账号、举报、拉黑、封禁、申诉、权限拒绝、推送、定位、弱网。

## 9. 商业化、IAP、虚拟资产

- [x] 明确日本上线商业模式：免费、第三方票务外链；现阶段无自营票务盈利系统、无会员、无数字装扮、无积分/点数、无推广位。（`docs/APP_STORE_REVIEW_NOTES_JA_DRAFT.md` 已说明）
- [x] 若仅第三方票务外链，App 内明确由第三方售票方提供。（当前仅展示活动主办方/第三方票务链接，RaveHub 不售票、不处理支付/退款/入场、不抽取票务佣金；App 文案改为票务外链/打开外部链接）
- [ ] 若自营数字内容/会员/装扮/积分，iOS 内使用 StoreKit/IAP。
- [ ] 购买凭证校验、恢复购买、退款通知、订阅管理。
- [ ] 虚拟资产不可转让、不可提现、不可兑换现金、是否过期的规则说明。
- [ ] 随机获得付费虚拟物品时披露概率、抽取记录、保底规则。
- [ ] 资金结算法/前払式支払手段风险由日本法务确认。

## 10. 年龄分级、未成年人、版权

- [ ] App Store Connect 年龄问卷按 UGC、聊天、位置共享、活动/酒精场景如实填写。
- [x] 注册或关键功能前采集出生年份/年龄段。（日本区域默认开启；iOS 注册表单采集出生年份；BFF 注册校验 `birthYear/regionCode`、拒绝 13 岁以下；User 持久化 `regionCode/birthYear/ageBand/guardianContactEmail/ageDeclaredAt`；登录/注册响应返回年龄段）
- [x] 未成年人限制陌生人私信、位置共享、夜间第三方票务外链跳转、成人内容曝光。（陌生人私信/位置共享/深夜第三方票务外链已接入区域合规策略；成人内容作为平台禁止内容处理，不做年龄门控分发，通过举报、审核、下架和处罚阻断曝光；法务与 Review Notes 已说明）
- [x] 家长/监护人联系通道。（`/legal/minor-safety` 已写明 App 内客服、举报/申诉入口和 `support@raver.app`；Review Notes 已补）
- [x] `minor_safety` 举报原因最高优先级。（举报原因已存在；后台优先级最高现有 bucket `high`，SLA 12h）
- [x] 用户上传或提交音乐/视频链接时确认拥有权利或链接来源合法。（服务端 `contentCompliance` 校验 Set/ID 与音乐/视频/音频链接提交；iOS Set 上传、Circle ID 发布已加确认；审核备注记录 `compliance.rights`）
- [x] 版权投诉页面和反通知流程。（`/legal/copyright` 已提供三语版权投诉、反通知和提交者权利/来源确认说明）
- [x] 后台可处理版权投诉、临时下架、恢复、处罚重复侵权用户。（Admin 内容举报队列支持 `copyright` 投诉详情、临时下架/恢复元数据、目标内容状态处理、重复侵权计数与警告/限制/封禁处罚）
