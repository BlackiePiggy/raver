# Raver 登录态与后台管理商用化补齐计划

> Status: Active Draft  
> Owner: Backend / Web Admin / iOS / Security / Operations  
> Created: 2026-05-16  
> Last Updated: 2026-05-16  
> Applies To: `server/`, `web/`, `mobile/ios/RaverMVP/`, `server/prisma/schema.prisma`, `docs/`  
> Related: `docs/AUTH_LOGIN_STATE_FULL_GUIDE.md`, `docs/DATABASE_BACKUP_GATEKEEPER.md`, `docs/RAVER_PLATFORM_ARCHITECTURE.md`, `docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md`

## 0. 文档目的

这份文档专门解决 Raver 当前“登录一次后的有效期、续期、安全退出、后台管理登录态、iOS 登录态、审计和运营可控性”这一块离商用还有哪些差距，以及如何按阶段补齐。

它不是泛泛的安全建议，而是后续执行用的主控文档。任何人接手这一块，都应该能从这里看到：

- 当前真实现状是什么。
- 商用目标状态是什么。
- 后台管理端和 iOS 端分别要做到什么程度。
- 哪些能力已经完成，哪些还没做。
- 每个阶段的 checkbox 进度。
- 数据库变更、环境变量、测试、上线门禁和回滚要求。

## 1. 当前结论快照

### 1.1 当前后台管理端

- [x] Web 后台当前使用 `web/src/contexts/AuthContext.tsx` 管理登录态。
- [x] Web 后台当前调用旧接口 `POST /api/auth/login`。
- [x] Web 后台当前把 `token` 存在 `localStorage`。
- [x] Web 后台当前访问管理接口时通过 `Authorization: Bearer <token>` 传 access token。
- [x] 当前本机 `server/.env` 已配置 `ACCESS_TOKEN_EXPIRES_IN=15m`。
- [x] Web 后台已接入 `/v1/auth/refresh`。
- [x] Web 后台已使用 HttpOnly refresh cookie 维持会话。
- [x] Web 后台已实现服务端强制 idle timeout。
- [x] Web 后台已实现后台专用 absolute timeout。
- [~] Web 后台已为账号处罚写操作、账号删除重试和到期处理接入密码二次验证；批量通知、删除内容、权限调整等其他高风险操作待扩展。
- [~] Web 后台已实现当前账号会话列表、指定会话撤销、管理员查看/踢下线其他用户会话；全端登出后台入口待补。

当前有效期判断：

- 如果目标环境配置了 `ACCESS_TOKEN_EXPIRES_IN=15m`，后台管理端一次登录后的 API 鉴权有效期是 15 分钟。
- 如果某个部署环境没有显式配置 `ACCESS_TOKEN_EXPIRES_IN`，代码会回退到旧 `JWT_EXPIRES_IN`，当前默认/旧配置是 7 天。
- Web 页面本地可能还保留 `localStorage.token`，但 token 过期后拉 profile 会失败并清掉登录态。

### 1.2 当前 iOS 端

- [x] iOS 当前使用 `/v1/auth/login`、`/v1/auth/sms/login`、`/v1/auth/register`、`/v1/auth/refresh`、`/v1/auth/logout`。
- [x] iOS 使用 access token + refresh token 双 token。
- [x] iOS access token 存入 Keychain。
- [x] iOS refresh token 存入 Keychain。
- [x] iOS access token 过期后会静默调用 `/v1/auth/refresh`。
- [x] iOS refresh token 已在后端执行轮换，旧 refresh token 会被 revoke。
- [x] iOS refresh 失败后会清理本地 token 并回到登录态。
- [x] 当前配置目标为 `ACCESS_TOKEN_EXPIRES_IN=15m`、`REFRESH_TOKEN_EXPIRES_IN=30d`。
- [ ] iOS 尚未展示用户可理解的“登录即将过期/需要重新登录”状态。
- [ ] iOS 尚未提供用户侧设备会话管理入口。
- [ ] iOS 尚未覆盖真实生产短信、异常登录、账号风险冻结等完整路径。
- [ ] iOS 尚未完成真实设备端到端回归矩阵。

当前有效期判断：

- iOS access token：15 分钟。
- iOS refresh token：30 天。
- 用户体感：30 天内只要 refresh 成功，基本不需要重新登录。

## 2. 商用目标状态

### 2.1 统一认证协议

最终认证主线统一为 `/v1/auth/*`：

- `POST /v1/auth/login`
- `POST /v1/auth/sms/send`
- `POST /v1/auth/sms/login`
- `POST /v1/auth/register`
- `POST /v1/auth/refresh`
- `POST /v1/auth/logout`
- `POST /v1/auth/logout-all`
- `GET /v1/auth/sessions`
- `DELETE /v1/auth/sessions/:id`
- `GET /v1/profile/me`

旧 `/api/auth/*` 只保留迁移期兼容，不再新增能力。

### 2.2 推荐有效期策略

| 场景 | Access Token | Refresh / Session | Idle Timeout | Absolute Timeout | 备注 |
| --- | --- | --- | --- | --- | --- |
| iOS 普通用户 | 15 分钟 | 30 天，可轮换续期 | 不强制，依赖 refresh 和风控 | 90 天内至少重新登录一次，可二期 | C 端体验优先 |
| Web 后台管理员 | 10-15 分钟 | 8-12 小时 | 30 分钟无操作退出 | 12 小时必须重新认证 | 后台高权限，安全优先 |
| Web 后台超级管理员 | 10 分钟 | 4-8 小时 | 15-30 分钟无操作退出 | 8-12 小时必须重新认证 | 敏感操作要求二次验证 |
| 运营大屏/只读后台 | 15 分钟 | 12-24 小时 | 60 分钟 | 24 小时 | 必须只读且权限收窄 |

本项目首期建议落地：

- iOS：继续保持 access 15 分钟 + refresh 30 天。
- Web 后台：access 15 分钟 + refresh cookie 12 小时 + idle timeout 30 分钟 + absolute timeout 12 小时。
- 高风险后台操作：二次验证有效窗口 10 分钟。

### 2.3 参考标准

本计划采用以下公开安全基线作为参考：

- OWASP Session Management Cheat Sheet：要求服务端控制 session 生命周期，并建议同时考虑 idle timeout、absolute timeout、renewal timeout。  
  https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html
- OWASP JSON Web Token Cheat Sheet：JWT 不应被当成所有场景的默认答案，需要关注 token 存储、轮换、撤销和泄露窗口。  
  https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html
- NIST SP 800-63B：较高保证级别会要求周期性重新认证和不活动超时。Raver 后台不必机械照搬金融级要求，但应吸收其后台高权限会话思路。  
  https://pages.nist.gov/800-63-4/sp800-63b.html

## 3. 当前差距总表

| 模块 | 当前状态 | 商用目标 | 差距等级 |
| --- | --- | --- | --- |
| iOS token 模型 | 双 token + Keychain + refresh 轮换 | 增加设备管理、风险处置、真实设备回归 | 中 |
| Web 后台 token 模型 | 单 JWT + localStorage | access 内存 + refresh HttpOnly cookie | 高 |
| 会话撤销 | iOS logout 可撤销 refresh | 全端 logout、logout-all、指定设备撤销 | 中 |
| 后台 idle timeout | 无 | 30 分钟无操作退出 | 高 |
| 后台 absolute timeout | 无 | 12 小时强制重新认证 | 高 |
| 管理员会话可视化 | 无 | 后台可查看、踢下线、审计 | 高 |
| 敏感操作二次验证 | 无 | 封禁、批量通知、删除、权限调整前二次验证 | 高 |
| 登录限流 | 后端已有基础限流 | 接入监控、持久化风险事件、后台可查 | 中 |
| 审计 | 已有 AdminAuditLog，auth audit 多为结构化日志 | auth 事件落库、可检索、可导出 | 中 |
| 生产短信 | 有 mock 和接口 | 阿里云真实短信、模板、频控、异常处理 | 中 |
| 环境变量门禁 | 本地已配 TTL | dev/staging/prod 全环境检查和启动校验 | 中 |
| 测试 | 有 auth smoke/integration 记录 | Web/iOS/E2E/安全回归矩阵 | 中 |

## 4. 商用化执行总 Checklist

### Phase 0：冻结范围和基线

- [x] 确认当前 Web 后台仍在旧 `/api/auth/*` 单 JWT 栈。
- [x] 确认当前 iOS 已在 `/v1/auth/*` 双 token 栈。
- [x] 确认本机 `server/.env` 已配置 `ACCESS_TOKEN_EXPIRES_IN=15m`、`REFRESH_TOKEN_EXPIRES_IN=30d`。
- [x] 确认 refresh token 表 `auth_refresh_tokens` 已存在。
- [x] 确认短信验证码表 `auth_sms_codes` 已存在。
- [x] 确认后台审计表 `admin_audit_logs` 已存在。
- [x] 创建本主控文档。
- [ ] 在 `docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md` 增加本专项进度入口。
- [ ] 确认 dev/staging/prod 的认证环境变量现状。
- [ ] 确认 Web 后台是否允许短暂停机迁移登录态。
- [ ] 确认后台角色分级：`admin`、`operator`、未来 `super_admin` 是否需要立即拆分。
- [x] 确认二次验证方式首期采用密码复验；短信复验延后到生产短信通道完成后。

### Phase 1：后端会话模型补齐

- [x] 为 `AuthRefreshToken` 增加端类型字段：`clientType`，取值如 `ios`、`web_admin`、`web_public`、`android`。
- [x] 为 `AuthRefreshToken` 增加设备展示字段：`deviceName`、`deviceId`、`platform`、`appVersion`。
- [x] 为 `AuthRefreshToken` 增加会话生命周期字段：`idleExpiresAt`、`absoluteExpiresAt`。
- [~] 为 `AuthRefreshToken` 增加风险字段：`riskLevel` 已完成；`lastIpCountry`、`lastIpCity` 暂缓到风险识别批次。
- [x] 为 refresh 创建逻辑写入 client metadata。
- [x] 为 iOS refresh 会话保留 30 天 refresh TTL。
- [x] 为 Web Admin refresh 会话使用 12 小时 absolute TTL。
- [x] 为 Web Admin refresh 会话使用 30 分钟 idle TTL。
- [x] 在 `/v1/auth/refresh` 中校验 `revokedAt`、`expiresAt`、`idleExpiresAt`、`absoluteExpiresAt`。
- [ ] refresh 成功后更新 `lastUsedAt`。
- [x] refresh 成功后对 Web Admin 更新下一次 `idleExpiresAt`。
- [x] refresh 成功后继续执行 refresh token 轮换。
- [x] refresh 失败时清 cookie、写审计、返回稳定错误码。
- [x] 补充 `POST /v1/auth/logout-all`，撤销当前用户所有 refresh token。
- [x] 补充 `GET /v1/auth/sessions`，返回当前用户设备会话列表。
- [x] 补充 `DELETE /v1/auth/sessions/:id`，撤销指定设备会话。
- [x] 会话列表不返回 token hash、原始 token、完整 IP 等敏感值。
- [x] 删除/禁用账号时撤销该账号所有 refresh token。
- [x] 修改密码后撤销除当前会话外的 refresh token。
- [x] 账号封禁命中 login scope 时阻断 refresh。

### Phase 2：Web 后台迁移到商用登录态

- [x] 新建 Web Admin 专用 auth client，调用 `/v1/auth/login`。
- [x] Web Admin 登录成功后只把 access token 放内存态。
- [x] Web Admin refresh token 只通过 HttpOnly cookie 保存。
- [x] Web Admin 不再把主 token 存入 `localStorage`。
- [x] 清理 `localStorage.token` 的旧恢复逻辑。
- [x] 保留一次性迁移逻辑：发现旧 `localStorage.token` 时清理并要求重新登录。
- [x] Web Admin 启动时调用 `/v1/auth/refresh` 尝试恢复会话。
- [x] Web Admin API client 主线已统一从内存读取 access token。
- [x] API 收到 401 后自动调用 refresh 并重试一次。
- [x] refresh 失败后统一退出到登录页。
- [x] Web Admin 页面展示“会话已过期，请重新登录”。
- [x] Web Admin 在 idle timeout 前 2 分钟弹出续期提示。
- [x] 用户选择继续使用时调用 refresh 延长 idle session。
- [x] 用户无操作超过 idle timeout 后前端主动退出。
- [x] 后端仍作为最终裁决，不依赖前端计时。
- [ ] 后台页面权限统一通过 `getAdminCmsRolePolicy` 和后端 role policy 双重判断。
- [ ] 后台所有管理 API 收敛到 `/api/admin/v1` 或明确兼容期。
- [ ] 管理后台不再允许普通 `user` 进入 Admin Shell。

### Phase 3：后台高风险操作二次验证

- [~] 定义高风险操作清单：账号处罚写操作、账号删除重试和账号删除到期处理已落地；批量通知、删除内容、权限变更、虚拟资产发放、导出用户数据待逐个接入。
- [~] 高风险操作包括：永久封禁、解除封禁、批量通知、删除内容、账号删除重试、权限变更、虚拟资产发放、导出用户数据；首期已覆盖账号处罚创建、撤销、到期处理，以及账号删除重试、到期处理。
- [x] 新增 `POST /v1/auth/reauth`。
- [x] `reauth` 首期支持密码复验。
- [ ] 如短信通道生产可用，补充短信复验。
- [x] `reauth` 成功后签发短期 reauth proof，有效期 10 分钟。
- [x] reauth proof 只用于高风险操作，不可访问普通业务 API。
- [~] reauth proof 绑定用户、操作范围和过期时间；签名 proof 首期未绑定 refresh session id，后续 DB proof 批次补齐。
- [~] 后端高风险接口校验 reauth proof：账号处罚创建、撤销、到期处理，以及账号删除重试、到期处理已接入。
- [~] 前端高风险按钮触发二次验证弹窗：账号处罚后台、账号删除后台已接入。
- [x] 二次验证失败写审计。
- [x] 二次验证成功写审计。
- [x] 超过 10 分钟或切换账号后 reauth proof 失效。

### Phase 4：审计、风控和运营可见性

- [ ] 新增或扩展 auth 审计落库模型，覆盖登录、失败、refresh、logout、logout-all、session revoke、reauth。
- [ ] 审计字段包含 userId、action、outcome、clientType、ip、userAgent、reasonCode、createdAt。
- [ ] 敏感值脱敏，不记录原始 token、验证码、密码。
- [ ] 后台增加“登录与会话审计”页面。
- [ ] 后台可按用户、IP、时间、结果筛选审计。
- [ ] 后台用户详情页展示最近登录设备。
- [~] 后台用户会话支持踢下线；用户详情页内嵌入口待补。
- [ ] 账号处罚和账号删除操作联动会话撤销。
- [ ] 连续登录失败达到阈值写风险事件。
- [ ] 新设备/新地区登录写风险事件。
- [ ] 高风险登录可触发短信验证或重新登录。
- [ ] 管理员登录失败、二次验证失败进入单独告警指标。

### Phase 5：iOS 商用体验补齐

- [x] iOS token 已使用 Keychain。
- [x] iOS refresh 失败会清理登录态。
- [x] iOS 请求 401 后会尝试 refresh 并重试。
- [x] iOS 登录态失效提示已按 refresh 过期、会话撤销、idle/absolute 过期、账号停用分流。
- [x] iOS 设置页增加“登录设备”入口。
- [x] iOS 设备列表展示当前设备、最近活跃时间和大致位置。
- [x] iOS 支持撤销其他设备会话。
- [x] iOS 支持 logout-all。
- [ ] iOS 修改密码后提示是否退出其他设备。
- [x] iOS 收到 `ACCOUNT_INACTIVE`、`AUTH_SESSION_REVOKED`、`AUTH_REFRESH_EXPIRED` 时展示差异化文案。
- [ ] iOS 真机验证 Keychain 在重启、升级、杀进程后的恢复行为。
- [ ] iOS 真机验证 refresh token 轮换失败和网络中断边界。
- [ ] iOS 真机验证短信登录生产通道。

### Phase 6：短信登录生产化

- [ ] 确认阿里云短信签名和模板审核完成。
- [ ] 生产环境关闭 `AUTH_SMS_DEBUG_RETURN_CODE`。
- [x] 生产环境强制 `AUTH_SMS_PROVIDER=aliyun`，否则启动失败。
- [x] 单手机号发送冷却 60 秒。
- [x] 单手机号 1 小时最多 5 次。
- [x] 单 IP 1 小时最多 30 次。
- [x] 验证失败累计达到阈值后临时冻结。
- [x] 验证码只存 hash，不存明文。
- [x] 日志和审计中手机号脱敏。
- [x] 短信发送失败返回稳定错误码。
- [x] 后台可查看短信发送失败率和限流情况。
- [x] 后端新增 Firebase Phone ID token 登录入口，绕过自建短信 provider 后继续签发 Raver access/refresh session。
- [x] iOS 接入 FirebaseAuth SDK 和 `GoogleService-Info.plist`，用 Firebase Phone Auth 获取 ID token。
- [x] iOS 登录/注册手机号输入改为国家区号选择 + 本地手机号，首批覆盖日本、中国大陆、美国、加拿大、英国、韩国、新加坡、港澳台及部分欧洲国家。
- [x] iOS 注册页改为手机号验证码优先：Firebase Phone Auth 成功后换 Raver session，新手机号自动创建账号并提交昵称、出生年份和地区合规参数。
- [x] 注册页新增昵称可用性检测：后端提供 `GET /v1/auth/display-name/check`，iOS 昵称输入防抖查询并在冲突时禁用提交。
- [x] iOS 注册页已采集完整出生年月日；当前后端仍只持久化 `birthYear`，完整生日落库需后续 schema 迁移。
- [ ] 邮箱验证码注册/登录：需要新增后端 email verification code provider、发送/校验 API 和频控后再接入 iOS/Web。
- [ ] 真机完成中国大陆、海外手机号至少各一条测试路径，如业务范围适用。

### Phase 7：环境变量和启动门禁

- [ ] 整理 `server/.env.auth.example`，补齐所有 auth 变量说明。
- [ ] dev 环境确认 `ACCESS_TOKEN_EXPIRES_IN=15m`。
- [ ] staging 环境确认 `ACCESS_TOKEN_EXPIRES_IN=15m`。
- [ ] production 环境确认 `ACCESS_TOKEN_EXPIRES_IN=15m`。
- [ ] dev/staging/prod 确认 `REFRESH_TOKEN_EXPIRES_IN=30d`。
- [ ] production 确认 `JWT_SECRET`、`ACCESS_TOKEN_SECRET` 是强随机值。
- [ ] production 禁止使用默认 `your-super-secret-jwt-key-change-in-production`。
- [ ] production 设置 `AUTH_COOKIE_SECURE=true`。
- [ ] production 设置正确 `AUTH_COOKIE_DOMAIN`。
- [ ] production 设置 `AUTH_REFRESH_COOKIE_PATH=/v1/auth`。
- [ ] 服务启动时检测生产环境缺失关键 auth env 则失败退出。
- [ ] CI 增加 auth env lint 或 deployment checklist。

### Phase 8：测试与验收

- [ ] 后端单元测试覆盖 duration parser。
- [x] 后端集成测试覆盖 login -> refresh -> rotated old refresh rejected。
- [x] 后端集成测试覆盖 logout 后 refresh 失败。
- [x] 后端集成测试覆盖 logout-all。
- [x] 后端集成测试覆盖 session list。
- [x] 后端集成测试覆盖 revoke one session。
- [~] 后端集成测试覆盖 Web Admin idle timeout：当前覆盖 `web_admin` 会话创建和列表类型，时间过期边界待补可控 TTL 测试。
- [~] 后端集成测试覆盖 Web Admin absolute timeout：当前覆盖 `web_admin` 会话创建和列表类型，时间过期边界待补可控 TTL 测试。
- [x] 后端集成测试覆盖 iOS 30 天 refresh TTL 不受后台 12 小时策略影响。
- [~] Web E2E 覆盖登录、刷新页面恢复、API 401 自动 refresh：已覆盖登录后主 token 不落 localStorage、`/admin` API 401 自动 refresh 并重试成功；刷新页面恢复待补。
- [x] Web E2E 覆盖会话列表和指定设备撤销。
- [x] Web E2E 覆盖管理员检索并踢下线其他用户会话。
- [x] Web E2E 覆盖账号处罚创建前密码二次验证，并确认请求携带 reauth proof。
- [x] Web E2E 覆盖账号删除重试前密码二次验证，并确认请求携带 reauth proof。
- [~] Web E2E 覆盖 idle 弹窗和自动退出：当前已覆盖撤销当前会话后的回登录态，定时 idle 弹窗待补可控计时测试。
- [x] Web E2E 覆盖 localStorage 旧 token 清理。
- [x] Web E2E 覆盖 XSS 基础检查：主 token 不落 localStorage。
- [ ] iOS UI Test 覆盖登录态持久化。
- [~] iOS UI Test 覆盖 refresh 失败回登录页：当前已完成 AppState 差异化提示和 iOS build，UI 自动化待补。
- [ ] 真机回归覆盖弱网、杀进程、重启、升级。
- [ ] 安全回归覆盖 token 不出现在日志、URL、错误响应中。
- [ ] 管理后台人工验收踢下线和二次验证。

### Phase 9：上线和回滚

- [ ] 数据库变更前按 `docs/DATABASE_BACKUP_GATEKEEPER.md` 完成备份。
- [ ] migration 前记录备份文件和验证方式。
- [ ] staging 完成全链路演练。
- [ ] Web 后台迁移前通知运营重新登录窗口。
- [ ] 上线后监控 login success rate。
- [ ] 上线后监控 refresh success rate。
- [ ] 上线后监控 401/403 异常增长。
- [ ] 上线后监控短信发送失败率。
- [ ] 上线后监控 admin reauth failure。
- [ ] 准备 feature flag 回退 Web Admin 新 auth client。
- [ ] 准备兼容期内回退旧 `/api/auth/login` 的明确步骤。
- [ ] 上线 24 小时后复盘 auth 审计和错误日志。

## 5. 数据库改造门禁

本专项涉及 `auth_refresh_tokens`、auth 审计、可能的 reauth proof/session 表。任何 schema migration 或批量数据动作前，必须执行以下 checklist。

### Database Change Preflight

- [ ] 已确认数据库环境：local / dev / staging / production。
- [ ] 已确认本次操作范围。
- [ ] 已确认影响表。
- [ ] 已确认是否涉及 source of truth。
- [ ] 已执行备份。
- [ ] 已验证备份可读。
- [ ] 已记录备份到 tracker。
- [ ] 已准备回滚方式。
- [ ] 已准备验证命令。

最低备份命令：

```bash
mkdir -p backups
pg_dump "$DATABASE_URL" --format=custom --file "backups/raver_$(date +%Y%m%d_%H%M%S)_before_auth_session_commercialization.dump"
pg_restore --list "backups/<dump-file>.dump" >/tmp/raver_restore_list.txt
wc -l /tmp/raver_restore_list.txt
```

## 6. 建议数据模型补齐

### 6.1 AuthRefreshToken 扩展

建议在现有 `AuthRefreshToken` 上扩展，而不是立即新建一套 session 表。

```prisma
model AuthRefreshToken {
  id                String    @id @default(uuid())
  userId            String    @map("user_id")
  tokenHash         String    @unique @map("token_hash")
  userAgent         String?   @map("user_agent")
  ipAddress         String?   @map("ip_address")
  expiresAt         DateTime  @map("expires_at")
  lastUsedAt        DateTime? @map("last_used_at")
  revokedAt         DateTime? @map("revoked_at")
  replacedByTokenId String?   @map("replaced_by_token_id")

  // Proposed commercial fields
  clientType        String?   @map("client_type")
  deviceId          String?   @map("device_id")
  deviceName        String?   @map("device_name")
  platform          String?   @map("platform")
  appVersion        String?   @map("app_version")
  idleExpiresAt     DateTime? @map("idle_expires_at")
  absoluteExpiresAt DateTime? @map("absolute_expires_at")
  riskLevel         String?   @map("risk_level")
}
```

### 6.2 AuthAuditLog

可以选择新建 `auth_audit_logs`，也可以短期复用结构化日志。但商用后台需要可检索、可导出、可关联用户详情页，因此建议落库。

建议字段：

- `id`
- `userId`
- `action`
- `outcome`
- `clientType`
- `sessionId`
- `ipAddressMasked`
- `userAgent`
- `reasonCode`
- `detail`
- `createdAt`

### 6.3 ReauthProof

二次验证 proof 可以用短期数据库记录，也可以用短期签名 token。首期建议服务端落库，便于撤销和审计。

建议字段：

- `id`
- `userId`
- `sessionId`
- `scope`
- `expiresAt`
- `consumedAt`
- `createdAt`

## 7. API 契约目标

### 7.1 登录成功响应

```json
{
  "token": "access-token",
  "accessToken": "access-token",
  "accessTokenExpiresIn": 900,
  "refreshToken": "ios-only-or-dev-compatible",
  "refreshTokenId": "session-id",
  "user": {},
  "accountStatus": {}
}
```

Web Admin 生产环境依赖 HttpOnly cookie，不应依赖响应体中的 refresh token。

### 7.2 Refresh 失败错误码

建议稳定错误码：

- `AUTH_REFRESH_TOKEN_MISSING`
- `AUTH_REFRESH_TOKEN_INVALID_OR_EXPIRED`
- `AUTH_SESSION_IDLE_EXPIRED`
- `AUTH_SESSION_ABSOLUTE_EXPIRED`
- `AUTH_SESSION_REVOKED`
- `AUTH_ACCOUNT_INACTIVE`
- `AUTH_ACCOUNT_ENFORCEMENT_BLOCKED`

### 7.3 会话列表响应

```json
{
  "items": [
    {
      "id": "session-id",
      "clientType": "ios",
      "deviceName": "iPhone",
      "platform": "iOS",
      "appVersion": "1.0.0",
      "createdAt": "2026-05-16T00:00:00.000Z",
      "lastUsedAt": "2026-05-16T01:00:00.000Z",
      "expiresAt": "2026-06-15T00:00:00.000Z",
      "isCurrent": true,
      "revokedAt": null
    }
  ]
}
```

## 8. 前端迁移原则

### 8.1 Web Admin

- access token 只存在 React state / 内存 store。
- refresh token 只存在 HttpOnly cookie。
- 不再用 `localStorage.token` 保存主登录凭据。
- 旧 localStorage token 只用于检测迁移，并立即清理。
- 所有 admin API 通过统一 fetch wrapper。
- wrapper 支持 401 后 refresh 一次并重试。
- refresh 失败统一跳登录页。
- 页面不直接拼 Authorization header，避免散落。

### 8.2 iOS

- access token 和 refresh token 继续使用 Keychain。
- refresh token 轮换成功后必须立即覆盖本地旧值。
- refresh 失败必须清理 access + refresh。
- 401 自动 refresh 只能重试一次，避免循环。
- 账号封禁、账号删除、refresh 过期、会话撤销需要不同文案。
- 设备会话管理首期可以放在设置页安全入口。

## 9. 后台管理安全策略

### 9.1 权限

- `admin`：可操作所有管理能力。
- `operator`：可处理日常内容、预报名、举报、部分账号处罚。
- `super_admin`：未来可选，用于永久封禁、权限变更、数据导出等最高风险动作。
- 普通 `user` 不应进入 Admin Shell。

### 9.2 高风险操作

首期必须二次验证：

- 永久封禁账号。
- 解除永久封禁。
- 批量发送通知。
- 删除或匿名化账号。
- 批量处理举报。
- 导出用户数据。
- 修改管理员权限。
- 发放虚拟资产或运营权益。

### 9.3 审计

每个高风险操作必须记录：

- actorId
- actorRole
- action
- targetType
- targetId
- before / after
- reasonCode
- note
- ip
- userAgent
- reauthProofId
- createdAt

## 10. 验收口径

这一块只有同时满足下面条件，才算“商用化补齐完成”：

- [ ] iOS 和 Web Admin 都统一到 `/v1/auth/*` 主协议。
- [x] Web Admin 不再把主 token 存入 localStorage。
- [ ] Web Admin 具备 HttpOnly refresh cookie。
- [x] Web Admin 具备 idle timeout 和 absolute timeout。
- [x] iOS 保持 Keychain + refresh rotation，并支持设备会话管理。
- [x] 用户可以查看并撤销设备会话。
- [x] 管理员可以踢下线。
- [~] 高风险后台操作具备二次验证：账号处罚写操作、账号删除重试和账号删除到期处理已完成，其他高风险操作待扩展。
- [ ] auth 审计可以后台检索。
- [ ] 登录失败、refresh 失败、会话撤销都有稳定错误码。
- [ ] dev/staging/prod 环境变量通过门禁。
- [ ] 生产短信通道关闭 debug code。
- [ ] 后端、Web、iOS、真机回归全部通过。
- [ ] 上线回滚方案已演练。

## 11. 执行日志

### 2026-05-16

- [x] 完成当前 Web Admin 与 iOS 登录态现状盘点。
- [x] 确认 Web Admin 当前仍是旧单 JWT + localStorage。
- [x] 确认 iOS 当前已经接入 `/v1/auth/*` 双 token + Keychain。
- [x] 新建本商用化补齐主控文档。
- [x] 把 Phase 0 / Phase 8 进度入口写入商业化 tracker。
- [x] 完成 Phase 1 后端会话模型补齐 migration preflight：本地库已备份并验证可读。
- [x] 新增 migration `20260516170000_expand_auth_refresh_tokens_for_sessions`，扩展 `auth_refresh_tokens` 会话字段。
- [x] 应用本地 migration 并完成 Prisma client generate。
- [x] 后端接入 client metadata、Web Admin idle/absolute timeout、session list、session revoke。
- [x] `pnpm build` 通过。
- [x] `AUTH_INTEGRATION_ENABLE_SMS=false pnpm auth:integration` 通过。
- [x] Web 增加 `/v1/*` rewrite，后台登录/注册/启动恢复切到 `/v1/auth/*`。
- [x] Web Admin 后台 API client 收敛到 `authenticatedJsonFetch`，`notification-center-admin` / `admin-status` / `admin-audit` 不再本地拼接 Authorization。
- [x] Web Admin 接入 28 分钟 idle 续期提示、30 分钟前端主动退出；后台路径会话过期跳转 `/login?reason=session-expired`，idle 超时跳转 `/login?reason=idle-timeout`。
- [x] 新增 Playwright Web E2E：覆盖 `/admin` 收到 401 后自动 refresh 并重试成功，以及 refresh 失败跳回登录页并展示过期提示。
- [x] `cd web && pnpm test:e2e` 通过。
- [x] `cd web && pnpm build` 通过。
- [x] Web Admin 新增 `/admin/auth-sessions` 当前账号登录设备与会话页面，展示 client type、设备、平台、最近活跃、idle/absolute/refresh 过期时间和当前会话标记。
- [x] Web Admin 会话页面支持撤销其他会话；撤销当前会话后清登录态。
- [x] 后台工作台新增“登录设备与会话”入口。
- [x] Playwright Web E2E 扩展到 4 条：401 refresh retry、refresh 失败回登录、会话列表撤销其他设备、撤销当前会话回登录态。
- [x] `cd web && pnpm test:e2e` 通过。
- [x] `cd web && pnpm build` 通过。
- [x] 后端新增 Admin Auth Sessions API：`GET /api/admin/v1/auth-sessions` 支持按 userId / 邮箱 / 用户名 / 昵称检索会话，`POST /api/admin/v1/auth-sessions/:id/revoke` 支持管理员踢下线，权限为 `admin`。
- [x] 管理员踢下线写入 `AdminAuditLog`，会话列表继续只返回 masked IP，不返回 token hash 或原始 refresh token。
- [x] Web Admin `/admin/auth-sessions` 增加 admin-only “用户会话检索与踢下线”区块。
- [x] Playwright Web E2E 扩展到 5 条：新增管理员检索目标用户会话并踢下线。
- [x] 新增 `POST /v1/auth/reauth`，当前 access token + 密码复验成功后签发 10 分钟 reauth proof。
- [x] 账号处罚创建、撤销、到期处理要求 `x-raver-reauth-proof`，proof 绑定 userId 和 `account_enforcement.write` scope。
- [x] Web Admin 账号处罚页面新增安全复验弹窗，10 分钟窗口内复用 reauth proof。
- [x] Playwright Web E2E 扩展到 6 条：新增账号处罚创建前密码复验，并确认创建请求携带 reauth proof。
- [x] 账号删除重试、到期处理要求 `x-raver-reauth-proof`，proof 绑定 userId 和 `account_deletion.write` scope。
- [x] Web Admin 账号删除页面新增安全复验弹窗，10 分钟窗口内复用 reauth proof。
- [x] Playwright Web E2E 扩展到 7 条：新增账号删除重试前密码复验，并确认重试请求携带 reauth proof。
- [x] `cd server && pnpm build` 通过。
- [x] `cd web && pnpm build` 通过。
- [x] `cd web && pnpm test:e2e` 通过。
- [x] `cd server && pnpm build` 通过。
- [x] `cd web && pnpm build` 通过。
- [x] `cd web && pnpm test:e2e` 通过。
- [x] Web AuthContext 改为 access token 内存态，并清理旧 `localStorage.token`。
- [x] Web Admin status / audit / notification center client 改为从内存 token helper 读取。
- [x] Web Admin account/content/pre-registration client 改为统一 authenticated fetch wrapper。
- [x] `cd web && pnpm build` 通过；仅有既有 lint warning。
- [x] Playwright Web E2E 扩展到 9 条：新增旧 `localStorage.token` 启动清理，以及登录后 access token 不落 `localStorage`。
- [x] `cd web && pnpm build` 通过；仅有既有 lint warning。
- [x] `cd web && pnpm test:e2e` 通过；已清理 `web/test-results`。
- [x] iOS `SocialService` 增加登录设备列表、撤销设备和 logout-all 能力，走 `/v1/auth/sessions`、`DELETE /v1/auth/sessions/:id`、`POST /v1/auth/logout-all`。
- [x] iOS 设置页新增“登录设备”入口，支持展示当前设备、最近活跃、平台、版本和 masked IP，并可撤销设备或退出全部设备。
- [x] iOS 登录态失效通知增加 reason，refresh 过期、会话撤销、idle/absolute 过期、账号停用展示差异化文案。
- [x] `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` 通过；存在既有 warning。
- [x] 后端 auth integration 补充 logout-all 全会话撤销断言，以及 iOS 30 天 refresh TTL / Web Admin 12 小时 TTL 分流断言。
- [x] `cd server && pnpm build` 通过。
- [x] `cd server && AUTH_INTEGRATION_ENABLE_SMS=false pnpm auth:integration` 通过。
- [x] 新增 `POST /v1/auth/password`，修改密码后保留当前 refresh 会话并撤销其他 refresh token。
- [x] 账号删除/停用路径统一通过 refresh token revoke helper 撤销该账号所有 refresh token。
- [x] 后端 auth integration 补充修改密码踢掉其他会话、删号后当前/其他会话均无法 refresh 的断言。
- [x] `cd server && pnpm build` 通过。
- [x] `cd server && AUTH_INTEGRATION_ENABLE_SMS=false pnpm auth:integration` 通过。
- [x] 短信 provider 增加生产环境启动门禁：production 必须使用 `AUTH_SMS_PROVIDER=aliyun` 且阿里云配置完整，不能 fallback 到 mock。
- [x] `/v1/auth/sms/send` 和 `/v1/auth/sms/login` 返回稳定 `AUTH_SMS_*` 错误码，并记录发送、失败、限流、验证失败指标。
- [x] Web Admin 工作台接入 Auth SMS 只读状态：provider、production safe、发送失败率、限流、验证失败、缺失阿里云配置。
- [x] 新增 `POST /v1/auth/firebase-phone/login`：服务端验证 Firebase ID token 的 `phone_number` 后，复用手机号账号创建、处罚阻断和 Raver session 签发。
- [x] iOS `SocialService` / `AppState` 增加 Firebase Phone ID token 换 Raver session 的服务层入口。
- [x] iOS 已加入 FirebaseAuth Pod、复制 `GoogleService-Info.plist` 到主 App target，并在启动和 URL callback 处接入 Firebase Auth；APNs token 保持 Firebase 默认 swizzling 自动处理，不手动调用 `setAPNSToken`。
- [x] iOS 已补 Firebase Phone Auth 回跳配置：`Info.plist` 增加 encoded app id URL scheme，并在 remote notification 回调中优先交给 `Auth.auth().canHandleNotification`。
- [x] 本地后端通过被忽略的 `server/.env` 指向 Firebase Admin service account 文件；service account JSON 不进入 git。
- [x] `cd server && pnpm build` 通过。
- [x] `cd web && pnpm build` 通过；仅有既有 React hook / `<img>` lint warning。
- [x] `AUTH_INTEGRATION_BASE_URL=http://127.0.0.1:3911/v1 AUTH_INTEGRATION_ENABLE_SMS=false AUTH_FIREBASE_PHONE_MOCK=true pnpm auth:integration` 通过；覆盖 Firebase phone mock 成功登录和无效 token 401。
- [x] `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` 通过；存在既有 Pods script warning。
- [x] `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` 通过；验证 Firebase Phone Auth URL scheme / notification callback 补丁可编译。
