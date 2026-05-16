# Raver 上线阶段差距分析

生成时间：2026-05-16 20:55 CST  
分析范围：`server/`、`web/`、`mobile/ios/RaverMVP/`、`docs/`、`.github/`、项目根配置  
结论等级：当前不建议直接上线。项目已经具备较多商用化能力雏形，但仍处在“开发/灰度前准备”而非“可正式发布”状态。

## 1. 总体判断

Raver 当前是 App-first 的复合型产品：iOS Native 主客户端、Node/Express/Prisma 后端、Next.js Web/Admin、PostgreSQL、Redis、Tencent IM、Firebase Phone Auth、APNs、内容审核、账号处罚、账号删除、Check-in projection、分享短链、通知中心等模块已经铺开。

从上线视角看，项目的核心问题不是“没有功能”，而是发布工程和生产闭环还没有收束：

- Web 生产构建当前失败，会直接阻断 Web/Admin 上线。
- 后端可以通过 TypeScript 编译和 Prisma schema 校验，但生产入口仍有开发态配置，如全开放 CORS、`morgan('dev')`、默认错误打印和缺少生产部署清单。
- iOS 工程可以被 Xcode 识别，Release 模拟器构建已启动验证，但工作区存在大量未提交 Pods、Firebase、迁移、后台改动，发布基线不干净。
- 认证专项近期明显加强，但生产环境密钥、Cookie 域、安全日志、短信、Firebase、APNs、真实设备回归仍需要用发布门禁锁住。
- CI 覆盖面偏窄，没有把 Web build、Web E2E、iOS build、迁移演练、生产配置校验作为必过项。
- 运维侧缺少正式的部署拓扑、备份恢复演练、监控告警、日志脱敏策略、容量/压测基线和回滚流程。

## 2. 当前验证结果

本次实际执行了以下检查：

| 检查项 | 命令 | 结果 |
|---|---|---|
| 后端 TypeScript 构建 | `cd server && pnpm build` | 通过 |
| Prisma schema 校验 | `cd server && pnpm exec prisma validate` | 通过 |
| Web 生产构建 | `cd web && pnpm build` | 失败 |
| Web E2E 用例枚举 | `cd web && pnpm exec playwright test --list` | 通过，当前 9 条 |
| Web E2E 包脚本参数验证 | `pnpm test:e2e -- --list` | 失败，参数被 Playwright 当作测试过滤 |
| Xcode workspace 枚举 | `xcodebuild -list -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace` | 通过 |
| iOS Release 模拟器构建 | `xcodebuild ... -configuration Release ... build CODE_SIGNING_ALLOWED=NO` | 未完成；已通过依赖解析、Pods/第三方 SDK 多数编译并进入主 App Swift 编译，因耗时过长手动停止，需单独完整验证 |

Web 构建失败的关键错误：

```text
unhandledRejection [Error [PageNotFoundError]: Cannot find module for page: /_document]
```

同时 Web build 还暴露了若干警告：React Hook 依赖缺失、多处 `<img>` 未使用 Next Image。这些不是当前失败主因，但上线前应治理或明确接受。

## 3. P0 阻断项

### P0-1 Web/Admin 生产构建失败

影响：后台、CMS、预报名、公网页面无法进入可靠发布流水线。  
证据：`cd web && pnpm build` 在 page data 阶段失败，报 `Cannot find module for page: /_document`。  
建议：

- 先修复 Next.js 构建失败，确认 App Router / Pages Router 混用状态。
- 在 CI 中新增 `cd web && pnpm install --frozen-lockfile && pnpm build`。
- 构建通过后再跑 `pnpm exec playwright test`，不要只枚举用例。

### P0-2 发布基线不干净

影响：无法判断哪些代码是准备上线的版本，Pods、Firebase、新迁移、后台 session 改造和文档改动混在同一个工作区。  
证据：`git status` 显示大量 modified / added / untracked，包括 `server/prisma/migrations/20260516*`、`server/src/services/firebase-phone-auth.service.ts`、`mobile/ios/RaverMVP/Pods/Firebase*`、`GoogleService-Info.plist`、`web/tests/`、`web/playwright.config.ts` 等。  
建议：

- 先冻结一个 release candidate 分支。
- 按后端、Web、iOS、迁移、文档拆分提交或 PR。
- 清理 `.DS_Store`、构建产物、Xcode 用户态文件、无关 dump/backup。
- 明确 Pods 是否纳入仓库。如果纳入，去掉用户态 `xcuserdata`；如果不纳入，补 `.gitignore` 和安装流程。

### P0-3 缺少生产部署清单

影响：即使代码能跑，也没有可复现、可审计的生产部署路径。  
证据：根目录只有开发 `docker-compose.yml`，未发现 `Dockerfile`、生产 compose、Vercel/Render/Fly/Procfile 等发布配置。  
建议：

- 为 `server` 定义生产镜像或明确 PaaS 部署方式。
- 为 `web` 定义生产构建和运行环境。
- 明确 Postgres/Redis/对象存储/APNs/Firebase/Tencent IM 的生产环境变量来源。
- 建立 staging 环境，所有迁移和关键回归先在 staging 演练。

## 4. 后端生产差距

### 4.1 入口安全配置仍偏开发态

当前 `server/src/index.ts` 使用：

- `app.use(cors())`：默认允许任意 Origin。
- `morgan('dev')`：生产日志格式和敏感字段控制不足。
- 500 handler 中 `console.error(err.stack)`：需要接入脱敏和结构化日志策略。
- `/uploads` 本地静态目录：生产应优先走 OSS/CDN，并限制本地 fallback。

建议上线前完成：

- CORS allowlist：只允许正式 Web/Admin 域名、必要的 staging 域名。
- 请求 ID / trace ID：贯穿 access log、错误日志、审计日志。
- 生产错误响应：不要泄漏 stack、SQL、第三方错误细节。
- 限流统一化：登录/SMS 已有内存限流，但生产多实例下需要 Redis 或网关级限流。
- 健康检查拆分：`/health` 只表示进程活着；需要 `/ready` 检查 DB、Redis、关键第三方开关。

### 4.2 认证体系有进展，但门禁还不够硬

已具备：

- Access token + refresh token。
- Refresh token hash 存储和轮换。
- Web Admin access token 内存态，不再落 `localStorage`。
- Refresh cookie HttpOnly、SameSite=Lax，生产默认 secure。
- Web E2E 覆盖 9 条 auth session 场景。
- SMS provider 在 production 下要求 Aliyun。
- Firebase Phone Auth 服务端验证入口。

仍需完成：

- 生产必须拒绝默认 JWT secret：当前 `ACCESS_TOKEN_SECRET` 会 fallback 到 `JWT_SECRET`，而 `JWT_SECRET` 又 fallback 到 `your-super-secret-jwt-key-change-in-production`。
- `.env.example` 不完整：目前只有 auth/openim example，缺少统一生产 env 清单。
- 生产 Cookie 域、路径、secure、sameSite 需要发布前自动校验。
- 认证日志要验证“不打印原始 token、验证码、密码、完整手机号/IP”。
- Web E2E 文档中仍提到刷新页面恢复待补；需要实际覆盖。

### 4.3 数据库迁移风险偏高

现状：

- Prisma schema 校验通过。
- 迁移数量很多，且 2026-05-15 至 2026-05-16 有大量新增迁移，涉及合规、账号删除、处罚、内容 i18n、认证 session、排行榜等。
- 仓库中存在 `backups/raver_20260516_165823_before_auth_session_commercialization.dump`，说明已经意识到备份门禁，但它不应混入 release 改动。

上线前需要：

- 在 staging 执行 `prisma migrate deploy`，记录耗时和锁表风险。
- 对所有 backfill / projection rebuild 脚本建立顺序清单。
- 数据库备份恢复演练：不仅要有 dump，还要验证可恢复、可读、可回滚。
- 为高风险表建立容量预估和索引验证，如 feed、comments、notifications、checkins projection、IM sync jobs、audit logs。

### 4.4 后台管理与审计仍需闭环

已看到 admin audit、account enforcement、account deletion、content reports、content submissions 等模块。上线前还缺：

- Admin RBAC 的角色矩阵和最小权限确认。
- 关键操作的二次认证覆盖清单。
- 审计日志保留周期、查询入口、导出/留痕策略。
- 运营误操作回滚流程，如误封禁、误删内容、误触发账号删除。

## 5. Web/Admin 差距

### 5.1 构建阻断

`pnpm build` 失败是当前 Web 最大阻断。修复前不建议上线 Admin。

### 5.2 Next 配置过宽

`web/next.config.js` 里：

- `images.remotePatterns` 允许任意 `http` / `https` hostname。
- 默认 API URL 仍是 `http://localhost:3901/api`。
- Festival Viewer rewrites 指向默认 `http://127.0.0.1:8000`。

上线建议：

- 图片域名收敛到 OSS/CDN、Firebase/Tencent 必要域名。
- 生产禁止 fallback localhost。
- Festival Viewer 如果只是内部工具，应单独鉴权或下线公网 rewrite。
- 对 Admin 路由加统一鉴权守卫和角色守卫，不依赖页面内局部判断。

### 5.3 测试覆盖不足

当前 Playwright 能枚举 9 条，集中在 Web Admin auth session。仍缺：

- Admin 登录刷新页面恢复。
- Admin RBAC 越权访问。
- 内容审核、账号处罚、账号删除的完整 E2E。
- Web public 页面基础 smoke。
- CI 中实际执行 E2E。

## 6. iOS 差距

### 6.1 发布配置需要确认

当前 `AppConfig`：

- Debug 默认 `.mock`。
- Release 默认 `.live`。
- Release API 默认 `https://api.raver.app`。
- Real-name enforcement Release 默认开启。
- Tencent IM APNs Business ID 已在 Info.plist 中配置为 `48505`。

上线前必须确认：

- `https://api.raver.app` 已部署并通过 HTTPS、CORS、证书、健康检查。
- Bundle ID、App Group、Push、Associated Domains、Firebase URL scheme、APNs 环境一致。
- Release build 真机安装、登录、Firebase Phone Auth、Tencent IM、APNs、Widget、Notification Service Extension 全链路通过。
- `GoogleService-Info.plist` 是目标 bundle 对应的生产配置，并且允许被纳入仓库或改为 CI 注入。

### 6.2 Release 构建还没有形成可控门禁

本次 Release simulator build 已经进入主 App Swift 编译阶段，但耗时较长且出现大量第三方 SDK warning，最终未在本轮完成。需要注意：

- 当前命令未能给出“Release 构建通过”的硬结论。
- Exyte Chat / Tencent Chat UIKit 等第三方代码出现多处 deprecation warning 和 Swift concurrency warning，其中一部分在 Swift 6 语言模式下会升级为错误。
- CI 中 iOS build 目前只是手动 workflow_dispatch 可选项，不是 PR / release 必过项。

上线前建议建立独立 iOS release lane：

- `xcodebuild` 使用固定 DerivedData、固定 destination、合理超时和日志归档。
- Release simulator build 和 Archive 分开验证。
- 记录 warning 基线，对 Swift 6 会变错误的 warning 建 tracker。
- 真机 Archive / TestFlight 构建必须通过，不能只依赖模拟器。

### 6.3 iOS 自动化测试过少

当前只发现 `RaverMVPUITests/AuthSessionPersistenceUITests.swift`。对一个社交/活动/IM App 来说，上线前至少需要：

- 登录/登出/refresh 轮换真机或模拟器回归。
- 核心 tab 启动 smoke。
- 活动详情、打卡、Feed、IM、通知权限、账号删除入口 smoke。
- Deep link / Push route 回归。
- 弱网、token 过期、被封禁/注销用户态回归。

### 6.4 第三方 SDK 与隐私

好信号：

- 主 App、Widget、Notification Service 都有 `PrivacyInfo.xcprivacy`。
- Firebase、Tencent IM、SDWebImage 等 Pods 有 privacy manifest。

仍需确认：

- App Store Connect 隐私问卷与 `PrivacyInfo.xcprivacy` 一致。
- Giphy、Tencent IM、Firebase 是否涉及 tracking、device id、diagnostics、user content。
- 日本上线相关年龄、未成年人限制、真实姓名/实名提示、账号删除、举报/屏蔽是否符合文档中的合规要求。

## 7. 合规与信任安全差距

项目已有合规模块和文档，包括日本 App Store 合规、隐私数据地图、账号删除、举报、处罚、内容审核、区域合规策略。上线前要把它们从“文档/模块存在”推进到“可验证闭环”：

- App 内必须能找到隐私政策、服务条款、账号删除入口。
- 账号删除请求需要 SLA、状态通知、撤销窗口、数据擦除边界说明。
- 举报/屏蔽/处罚需要运营后台可处理、可审计。
- 未成年人策略需要在注册、IM、位置共享、成人内容、深夜活动跳转中被真实执行。
- 用户生成内容需要审核策略：文本、图片、头像、昵称、IM 消息、活动发布、评论。
- 数据保留周期要明确：日志、审计、IM、通知、删除用户数据、备份。

## 8. 运维与可观测性差距

当前缺少正式生产运维闭环：

- 没有统一生产部署文档。
- 没有监控指标清单和告警阈值。
- 没有错误追踪方案，如 Sentry 或等价方案。
- 没有 structured logging / log redaction 方案。
- 没有 DB/Redis/OSS/APNs/Tencent/Firebase 依赖健康面板。
- 没有容量压测基线，尤其是 feed、IM、notification outbox、check-in projection。
- 没有发布回滚流程和版本兼容策略。
- 没有灾备演练记录。

建议至少建立：

- `docs/PRODUCTION_DEPLOYMENT_RUNBOOK.md`
- `docs/RELEASE_CHECKLIST.md`
- `docs/ROLLBACK_RUNBOOK.md`
- `docs/OBSERVABILITY_AND_ALERTING.md`
- `docs/STAGING_MIGRATION_REHEARSAL_LOG.md`

## 9. CI/CD 差距

现有 `.github/workflows`：

- `auth-integration-guard.yml`：后端 auth integration，含 Postgres、migration deploy、server build。
- `mvvm-coordinator-guard.yml`：iOS 架构边界脚本，iOS build 仅 workflow_dispatch 可选。

缺口：

- Web build 没进 CI，因此当前失败没有被门禁拦住。
- Web E2E 没进 CI。
- 后端没有全量 route smoke 或 API contract test。
- iOS Release build 没作为 PR 必过项。
- 没有 secret scanning、dependency audit、license check。
- 没有 Prisma migration drift 检查。
- 没有生产 env schema 校验。

## 10. 建议上线前路线

### 第一阶段：解除硬阻断

1. 修复 `web pnpm build`。
2. 冻结 release candidate 分支，清理工作区和无关产物。
3. 补齐统一 `.env.example` / `.env.production.example`。
4. 建立 Web build、server build、Prisma validate、Playwright、iOS build 的 CI 门禁。

### 第二阶段：生产环境闭环

1. 建 staging 环境并完成迁移演练。
2. 配置生产 CORS、Cookie、JWT secret、Aliyun SMS、Firebase Admin、APNs、Tencent IM、OSS/CDN。
3. 接入日志脱敏、错误追踪、监控告警。
4. 完成备份恢复和回滚演练。

### 第三阶段：App Store / 用户信任闭环

1. 真机回归登录、IM、Push、Widget、账号删除、举报/屏蔽、未成年人限制。
2. 校验隐私政策、服务条款、App Store Connect 隐私问卷、Privacy Manifest。
3. 补齐 Admin 运营 SOP：内容审核、账号处罚、删除处理、审计查询。
4. 小流量 TestFlight / 内部灰度，再扩大范围。

## 11. 推荐 Go/No-Go 标准

达到以下条件前，建议保持 No-Go：

- Web/Admin `pnpm build` 通过，并纳入 CI。
- 后端生产配置门禁通过，默认 secret / localhost / mock provider 不可进入 production。
- iOS Release 真机构建和核心链路 smoke 通过。
- Staging 完成最新迁移和回滚演练。
- 账号删除、举报、屏蔽、处罚、隐私政策、服务条款可被用户和运营真实使用。
- 监控、告警、日志脱敏、备份恢复、回滚流程均有负责人和演练记录。

当前更准确的阶段判断：功能丰富的 pre-production / staging 准备期，而不是正式上线就绪期。
