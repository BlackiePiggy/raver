# Raver 登录态完整落地方案（全程指导版）

- 文档版本：v1.7（需求已冻结，开发进行中）
- 创建日期：2026-04-21
- 冻结日期：2026-04-21
- 最近更新：2026-04-22 09:10（已补齐 CI 守卫与 iOS UI 自动化用例）
- 适用仓库：`/Users/blackie/Projects/raver`
- 适用范围：`server` + `web` + `mobile/ios`（含未来 Flutter 对齐）
- 文档用途：
  - 指导从 0 到 1 建设“可上线的登录态闭环”
  - 统一多端认证契约
  - 记录需求确认、研发进度、关键日志与决策

---

## 0. 使用说明（先看）

这份文档不是“设计稿”，而是执行中的主文档。

使用方式：
1. 先看「第 2 章需求确认结果（已冻结）」。
2. 按「第 5 章 分阶段实施计划」推进。
3. 每完成一个子任务，更新「第 8 章 进度看板」。
4. 遇到异常、线上问题、关键排查，写入「第 9 章 重要日志」。
5. 任何方案变更，必须在「第 10 章 决策日志」记录原因。

---

## 1. 当前现状盘点（基于仓库实况）

### 1.1 已有能力（不是 0）

1. 后端已有登录/注册接口：
- `POST /api/auth/login`、`POST /api/auth/register`
- `POST /v1/auth/login`、`POST /v1/auth/register`

2. Web 已有基础登录态：
- `web/src/contexts/AuthContext.tsx` 使用 `localStorage(token)` 恢复会话。
- 页面已接入 `useAuth()` 做前端层面的登录判断。

3. iOS 已有登录页与登录流程骨架：
- `mobile/ios/RaverMVP/RaverMVP/Features/Auth/LoginView.swift`
- `AppState.session != nil` 会切换到主流程。

### 1.2 关键缺口（为什么你会感觉“还没做登录态”）

1. iOS 默认是 Mock 模式，不是 Live：
- `AppConfig.runtimeMode` 默认 `.mock`。
- 导致“有登录 UI，但不是稳定真实登录链路”。

2. iOS token 仅内存保存，不持久化：
- `SessionTokenStore.swift` 当前是内存变量，App 重启后会丢失登录态。

3. 后端目前是“单 JWT”模型：
- 无 `refresh token`、无会话轮换、无设备级登出。
- token 过期后需要完整重新登录。

4. Web 与 iOS 认证栈未统一：
- Web 主要走 `/api/*`。
- iOS 主要走 `/v1/*`。
- 后期策略变更成本高，且容易出现行为不一致。

5. 安全与可观测性不足：
- 缺少登录限流、防爆破、审计日志、会话管理面板。
- 缺少标准化 auth 错误码与排障信息。

---

## 2. 需求确认结果（已冻结）

冻结依据：产品负责人确认（2026-04-21）

1. 登录方式范围：`A + 手机号短信登录`
- 账号密码（用户名/邮箱）保留。
- 新增手机号 + 阿里云短信验证码登录。
- 第三方登录（Apple/微信/QQ）本期不做。

2. Web token 策略：`A`
- 方案保留为：`access token` 内存 + `refresh token` HttpOnly Cookie。
- 但 Web 不在本期范围内，放二期执行。

3. iOS token 策略：`A（Keychain）`
- 说明：Keychain 是 iOS 系统级“安全凭据保险箱”，数据加密存储，App 重启不丢，安全性高于 UserDefaults。
- 本期要求：iOS 的 `accessToken/refreshToken` 必须落 Keychain，不允许仅内存保存。

4. 登录有效期：`A`
- `access token`：15 分钟
- `refresh token`：30 天
- 说明：
- `access token` 是“短期通行证”，用于日常请求 API，过期快，泄露风险窗口更小。
- `refresh token` 是“续期凭证”，用于换新的 access token，本身不直接访问业务 API。

5. 首期端范围：`B`
- 本期仅做后端 + iOS。
- Web 登录态改造放到第二阶段。

6. 多设备登录管理：`B`
- 本期不做“设备列表/踢下线”。
- 数据模型先预留可扩展字段，避免后续迁移成本过高。

7. 登录失效体验：`A`
- 优先静默 refresh。
- refresh 失败再回登录页并提示“登录已失效，请重新登录”。

---

## 3. 目标与边界

### 3.1 本期目标

1. 登录态“可恢复、可刷新、可撤销、可观测”。
2. 多端认证行为统一（至少错误语义、过期处理统一）。
3. iOS 从“默认 mock”切到“可稳定 live 开发”。
4. 提供可上线的安全基线（限流、审计、会话失效）。

### 3.2 非目标（本期不做）

1. 不做完整 SSO/多租户身份中心。
2. 不做复杂风控（设备指纹/行为模型）。
3. 不做完整 OAuth 生态（如 GitHub、Google 登录），除非你确认要并入本期。

---

## 4. 推荐总体技术方案（默认方案）

## 4.1 统一认证模型

采用“双 token + 旋转刷新”模型：

1. `accessToken`（短期）
- 用途：请求 API 鉴权
- 建议 TTL：15 分钟

2. `refreshToken`（长期）
- 用途：换新 accessToken
- 建议 TTL：30 天
- 每次刷新执行“轮换”（旧 refresh 立即失效）

3. 服务端保存 refreshToken 的哈希摘要（不明文落库）
- 防止数据库泄露时 token 被直接利用

## 4.2 各端存储策略

1. Web：
- `accessToken`：内存态（Context/Store）
- `refreshToken`：HttpOnly + Secure + SameSite Cookie

2. iOS：
- `accessToken` + `refreshToken`：Keychain
- App 启动执行 session restore（先 refresh，再拉 profile）

3. Flutter（未来对齐）：
- `flutter_secure_storage` 与 iOS 同策略

## 4.3 契约统一原则

统一以 `/v1/auth/*` 为主认证协议：
- `/v1/auth/login`
- `/v1/auth/register`
- `/v1/auth/refresh`
- `/v1/auth/logout`
- `/v1/auth/logout-all`（可选）
- `/v1/profile/me`

`/api/auth/*` 保留一段迁移窗口，最终收敛为一套协议。

## 4.4 手机号短信登录（阿里云 SMS）

本期新增短信登录子链路（后端 + iOS）：

1. 新增接口
- `POST /v1/auth/sms/send`
- `POST /v1/auth/sms/login`

2. `POST /v1/auth/sms/send` 建议参数
```json
{
  "phone": "+60123456789",
  "scene": "login"
}
```

3. `POST /v1/auth/sms/login` 建议参数
```json
{
  "phone": "+60123456789",
  "code": "123456"
}
```

4. 服务端规则
- 验证码 6 位，默认 5 分钟过期。
- 发送频控：
- 单手机号 60 秒 1 次。
- 单手机号 1 小时最多 5 次。
- 单 IP 1 小时最多 30 次。
- 校验失败累计阈值（如 10 次）触发临时冻结（如 15 分钟）。
- 新手机号首次登录：自动创建用户（用户名按规则生成，可后续补全资料）。

5. 阿里云接入建议
- provider 封装为 `SmsProvider` 接口，阿里云是默认实现，便于未来替换。
- 验证码只存哈希，不存明文；日志中掩码手机号。

---

## 5. 分阶段实施计划（可直接执行）

## Phase 0：需求冻结与基线准备（0.5 天）

目标：冻结认证策略，避免返工。

实施步骤：
1. 完成第 2 章需求确认。
2. 决定是否保留 `/api/auth/*` 并行期（建议保留 2 周）。
3. 约定错误码规范（`AUTH_INVALID_CREDENTIALS`、`AUTH_TOKEN_EXPIRED` 等）。
4. 建立本分支与任务看板。

验收标准：
- 需求确认项全部有结论。
- 方案默认值/自定义值写入第 10 章决策日志。

---

## Phase 1：后端登录态内核改造（2~3 天）

目标：把后端从“单 JWT”升级到“可刷新/可撤销”的会话体系。

### 1. 数据层改造

建议新增表：`auth_refresh_tokens`

字段建议：
- `id`（uuid）
- `user_id`
- `token_hash`
- `device_id`（可选）
- `user_agent`
- `ip`
- `expires_at`
- `revoked_at`
- `created_at`
- `rotated_from_token_id`（可选）

可选新增：`auth_audit_logs`
- 记录 `login_success/login_failed/refresh/logout/revoke`。

### 2. 接口层改造

新增/改造接口：
1. `POST /v1/auth/login`
- 成功返回：`accessToken + user`，并下发 refresh（cookie 或 body，按端策略）

2. `POST /v1/auth/register`
- 同登录态创建逻辑

3. `POST /v1/auth/refresh`
- 校验 refresh，轮换 refresh，签发新 access

4. `POST /v1/auth/logout`
- 失效当前 refresh 会话

5. `POST /v1/auth/logout-all`（可选）
- 失效该用户全部 refresh 会话

6. `GET /v1/auth/sessions`（可选）
- 返回当前账号设备会话列表

### 3. 中间件与工具层

改造建议：
1. `server/src/utils/auth.ts`
- 拆分 access/refresh 签发与校验
- 不再使用单一 `JWT_EXPIRES_IN` 管全局

2. 鉴权中间件
- 统一识别 access token
- 统一 401 错误码与 message

3. 登录保护
- 增加登录接口限流（按 IP + identifier）
- 增加失败次数监控

### 4. 配置项建议

新增环境变量：
- `ACCESS_TOKEN_SECRET`
- `ACCESS_TOKEN_EXPIRES_IN=15m`
- `REFRESH_TOKEN_SECRET`
- `REFRESH_TOKEN_EXPIRES_IN=30d`
- `AUTH_COOKIE_DOMAIN`
- `AUTH_COOKIE_SECURE=true/false`
- `AUTH_REFRESH_COOKIE_NAME=raver_refresh_token`
- `AUTH_REFRESH_COOKIE_PATH=/v1/auth`
- `AUTH_SMS_PROVIDER=aliyun`（本地可先用 `mock`）
- `ALIYUN_SMS_ACCESS_KEY_ID`
- `ALIYUN_SMS_ACCESS_KEY_SECRET`
- `ALIYUN_SMS_SIGN_NAME`
- `ALIYUN_SMS_TEMPLATE_CODE_LOGIN`

### 5. 验收标准

1. access 过期后可自动 refresh。
2. refresh 轮换成功，旧 refresh 不能再用。
3. logout 后 refresh 失效。
4. 接口错误码可被客户端稳定识别。

---

## Phase 2：iOS 登录态闭环（本期，2~3 天）

目标：让 iOS 端具备“可恢复登录态”的真实体验。

### 1. 主要改造点

1. 将 `runtimeMode` 默认切到可控 live（至少在开发环境文档明确）。
2. `SessionTokenStore` 从内存实现升级为 Keychain。
3. `AppState` 增加启动恢复流程：
- 读取 token
- 尝试 refresh
- 拉取 `profile/me`
- 恢复 `session`

### 2. 安全升级

1. `LiveSocialService` 增加 401 自动 refresh。
2. refresh 失败时清空本地 token 并发出 `session expired`。
3. 防止并发请求导致多次 refresh（加互斥锁/actor guard）。

### 3. 验收标准

1. iOS 重启后仍能保持登录。
2. token 过期后可自动续期。
3. refresh 失效后正确回到登录态。

---

## Phase 3：Web 后台第二阶段（暂缓）

目标：Web 登录态升级（按需再启动）。

状态：本期不执行，等待你明确排期。

预留任务：
1. `web/src/contexts/AuthContext.tsx` 改为 refresh 驱动恢复。
2. 抽象统一 `http client`，支持 401 refresh + 请求重放。
3. 切换为 HttpOnly Cookie 持有 refresh token。
4. 验收：刷新浏览器后保持登录，access 过期自动续期，refresh 过期后跳登录。

## Phase 4：灰度上线与观测（后端+iOS，1~1.5 天）

目标：确保上线可观测、可回滚。

### 1. 监控指标（必须）

1. 登录成功率（按端分组）。
2. refresh 成功率。
3. 401/403 频率。
4. 登录失败 Top 原因（密码错、账号不存在、限流）。

### 2. 日志规范

关键日志字段：
- `traceId`
- `userId`（脱敏）
- `deviceId`
- `action`（login/refresh/logout）
- `result`
- `errorCode`
- `latencyMs`

### 3. 灰度策略

1. 先内部账号灰度。
2. 再 10% 用户。
3. 最后全量。

### 4. 回滚策略

1. 保留旧 `/api/auth` 流程开关。
2. 服务端可切回“仅 access 校验，不强依赖 refresh”。
3. 客户端开关回退为“到期重新登录”。

---

## 6. 详细任务拆解（按模块）

## 6.1 Backend 任务清单

- [x] Prisma 新增 refresh token 表（含迁移）
- [x] 新增 auth refresh/logout/logout-all 接口
- [x] 新增短信登录接口：`/v1/auth/sms/send`、`/v1/auth/sms/login`
- [x] 阿里云 SMS provider 接入与配置（含签名模板）
- [x] 验证码安全策略（哈希存储、过期、错误次数、限流）
- [x] utils/auth 拆分 access/refresh token 逻辑
- [x] 鉴权中间件统一错误码
- [x] 登录限流中间件（login/register）
- [x] 审计日志落库/落日志系统
- [x] 编写 auth 集成测试（login/refresh/logout/rotate/revoke）

## 6.2 Web 任务清单

- [ ] 本期暂缓，不纳入当前里程碑
- [ ] 二期启动时再拆分执行（见 Phase 3）

## 6.3 iOS 任务清单

- [x] SessionTokenStore 改 Keychain
- [x] AppState 增加 restoreSession() 启动链路
- [x] LiveSocialService 增加 refresh + 请求重放
- [x] iOS 新增手机号验证码登录 UI 与调用链路
- [x] 登录页到主流程切换避免闪屏
- [x] 失效后统一错误提示与回跳登录
- [ ] 新增 UI 测试：重启后保持登录

---

## 7. 测试与验收矩阵

### 7.1 功能测试

1. 登录成功（用户名/邮箱/手机号验证码）。
2. 登录失败（密码错误）。
3. 注册成功并自动登录。
4. access 过期自动 refresh。
5. refresh 过期后跳登录。
6. logout 后旧 refresh 不可用。
7. 多设备管理本期不测（需求冻结为不启用）。

### 7.2 安全测试

1. 暴力尝试触发限流。
2. 被撤销 refresh 无法换新 access。
3. token 篡改返回标准 401 错误。
4. Web 不可通过 JS 读取 refresh（若采用 HttpOnly）。

### 7.3 回归测试

1. Feed 发布/评论等需鉴权接口不受影响。
2. OpenIM bootstrap 在登录态恢复后正常。
3. 个人资料页、通知页、私信页都能稳定使用。

---

## 8. 进度看板（执行中持续更新）

## 8.1 里程碑总览

| 里程碑 | 状态 | 负责人 | 计划完成日 | 实际完成日 | 备注 |
|---|---|---|---|---|---|
| M0 需求冻结 | DONE | Product/研发 | 2026-04-21 | 2026-04-21 | 已确认 1~7 需求项 |
| M1 Backend refresh 能力 | DOING | Backend | 2026-04-22 |  | 本地迁移、限流、审计、集成测试脚本均已通过，且已补 CI `auth-integration-guard`，待目标环境同步配置并灰度验证 |
| M2 iOS 登录态闭环 | DOING | iOS | 2026-04-22 |  | 关键能力与 UI 自动化（重启恢复/失效回登录）已落地并通过，待补充 401 自动 refresh UI 场景与真机 live 回归 |
| M3 手机号短信登录（阿里云） | DOING | Backend+iOS | 2026-04-22 |  | 接口与 iOS UI 已打通，待阿里云生产参数验证与到达率确认 |
| M4 灰度与观测（后端+iOS） | TODO |  |  |  |  |

状态建议：`TODO / DOING / BLOCKED / DONE`

## 8.2 每日进展记录（模板）

| 日期 | 模块 | 今日完成 | 阻塞项 | 明日计划 |
|---|---|---|---|---|
| 2026-04-21 | Auth-Backend |  |  |  |
| 2026-04-21 | Auth-Backend | 新增 refresh token 会话表、短信验证码表、`/v1/auth/sms/send`、`/v1/auth/sms/login`、`/v1/auth/refresh`、`/v1/auth/logout`、`/v1/auth/logout-all`，并通过 `pnpm build` | 待执行数据库 migration 与阿里云模板参数配置 | 执行 migration，联调 iOS，补接口冒烟日志 |
| 2026-04-21 | Auth-Backend | 执行 `pnpm prisma migrate deploy`，成功应用 `20260421173000_add_pre_registration_tables` 与 `20260421200000_add_auth_refresh_and_sms_login`，`migrate status` 显示 up to date | 无 | 补充集成测试并接入登录限流与审计日志 |
| 2026-04-21 | Auth-Backend | 完成 API 冒烟：`register(201) -> refresh(200) -> logout(200) -> refresh(401)`，短信接口 `sms/send(201)`、`sms/login(错误码401)` 行为符合预期 | 发现当前环境 token 过期时间仍为 7d（来自旧 `JWT_EXPIRES_IN` 回退） | 在目标环境补齐 `ACCESS_TOKEN_EXPIRES_IN=15m`、`REFRESH_TOKEN_EXPIRES_IN=30d` 并复测 |
| 2026-04-21 | Auth-Backend | 通过临时实例验证 TTL 配置：`PORT=3902 ACCESS_TOKEN_EXPIRES_IN=15m REFRESH_TOKEN_EXPIRES_IN=30d` 下注册响应 `accessTokenExpiresIn=900` | 仅本地验证，尚未写入目标环境变量 | 将 TTL 配置同步到 dev/staging/prod 并复测 |
| 2026-04-21 | Auth-Backend | 新增登录/注册限流（IP+identifier 维度）与统一 auth 审计日志（success/failed/blocked）并通过 `pnpm build` | 审计日志当前为结构化日志输出，尚未独立 auth_audit 表 | 评估是否新增专用 auth 审计表并补落库 |
| 2026-04-21 | Auth-Backend | 限流冒烟通过：同一账号连续 11 次错误登录，第 11 次返回 `429`；同一注册标识第 11 次注册返回 `429`；回归冒烟 `register(201)->refresh(200)->logout(200)->refresh(401)` 通过 | 无 | 补充自动化测试覆盖限流与审计 |
| 2026-04-21 | Auth-Backend | 本地 `.env` 已落地 `ACCESS_TOKEN_EXPIRES_IN=15m`、`REFRESH_TOKEN_EXPIRES_IN=30d`、`AUTH_SMS_PROVIDER=mock` | 现网环境仍需同步同配置 | 将配置同步到 dev/staging/prod 并纳入部署检查 |
| 2026-04-21 | Auth-Backend | 新增 `pnpm auth:smoke` 自动化脚本（register/refresh/logout/refresh-after-logout + 可选 sms/send），在 `3906` 实例执行通过 | 阿里云真实收码需生产短信参数和测试手机号 | 联调时用 `AUTH_SMOKE_ENABLE_SMS=true` 开启短信冒烟 |
| 2026-04-21 | Auth-Backend | 落地“临时短信替代路径”：`AUTH_SMS_PROVIDER=mock` + 非生产可选 `AUTH_SMS_DEBUG_RETURN_CODE=true`，`/v1/auth/sms/send` 可回传 `debugCode` 供联调 | 仅允许非生产使用，避免验证码泄露风险 | 阿里云报备完成后切回 `AUTH_SMS_PROVIDER=aliyun` 并关闭 debug 返回 |
| 2026-04-22 | Auth-Backend | 新增 `pnpm auth:integration` 集成测试脚本，覆盖 account session、refresh rotation、login/register 限流、sms flow，并在 `3912` 端口实跑通过 | 仍依赖 `mock+debugCode` 覆盖短信登录成功路径 | 报备完成后补充 aliyun 真短信集成测试场景 |
| 2026-04-21 | Auth-iOS | 新增 Keychain token 持久化、启动 restoreSession、401 自动 refresh 重试、短信验证码登录 UI、登录态启动加载态；`xcodebuild`(workspace) 构建通过 | UI 自动化用例未补齐 | 完成 iOS 冒烟脚本与 UI 测试 |
| 2026-04-22 | Auth-Backend | 新增 GitHub Actions 工作流 `.github/workflows/auth-integration-guard.yml`，将 `pnpm auth:integration` 纳入 PR/Push 自动校验（含 Postgres 服务、迁移、构建、健康检查） | 待首轮线上 CI 运行结果回写 | 观察首轮 CI 执行，必要时调优超时与日志输出 |
| 2026-04-22 | Auth-iOS | 新增 `RaverMVPUITests` 并实跑通过 2 条用例：`testSessionPersistsAfterRelaunchInMockMode`、`testSessionExpiryFallsBackToLogin` | 登录页父级标识会覆盖子控件 id（测试侧已做 label 回退） | 后续补 401 自动 refresh UI 用例，并考虑调整登录页 root 标识策略 |
| 2026-04-21 | Build/Tooling | 确认 iOS 必须使用 `.xcworkspace` 构建，`xcodeproj` 直编会出现 `framework not found MJExtension` | 无 | 在团队开发规范中固化 workspace 构建命令 |

## 8.3 子任务燃尽（模板）

| 任务ID | 任务描述 | 优先级 | 状态 | Owner | PR | 备注 |
|---|---|---|---|---|---|---|
| AUTH-BE-001 | 新增 refresh token 表 | P0 | DONE | Backend |  | 迁移已在本地开发库执行并验证 |
| AUTH-BE-002 | 新增短信发送与验证码登录接口 | P0 | DOING | Backend |  | 代码完成，待阿里云配置联调 |
| AUTH-BE-003 | refresh/logout 会话轮换链路冒烟 | P0 | DONE | Backend |  | register/refresh/logout/refresh(401) 已通过 |
| AUTH-BE-004 | access/refresh TTL 环境变量落地 | P0 | DOING | Backend |  | 代码支持已就绪，待目标环境补齐 15m/30d 配置 |
| AUTH-BE-005 | 登录/注册限流（IP+identifier） | P0 | DONE | Backend |  | 错误登录第 11 次返回 429，行为符合预期 |
| AUTH-BE-006 | Auth 审计日志 | P0 | DONE | Backend |  | 已输出结构化 auth 审计日志（含 action/outcome/errorCode/ip） |
| AUTH-BE-007 | Auth 自动化冒烟脚本 | P0 | DONE | Backend |  | `pnpm auth:smoke` 已接入并实跑通过 |
| AUTH-BE-008 | 临时短信替代路径（mock+debugCode） | P0 | DONE | Backend |  | 已支持非生产回传 debugCode，且保留 aliyun 切回路径 |
| AUTH-BE-009 | Auth 集成测试脚本 | P0 | DONE | Backend |  | `pnpm auth:integration` 覆盖核心链路并实跑通过 |
| AUTH-BE-010 | Auth 集成测试接入 CI 守卫 | P0 | DONE | Backend |  | 已新增 `auth-integration-guard` 工作流，PR/Push 自动执行 |
| AUTH-IOS-001 | SessionTokenStore 改 Keychain | P0 | DONE | iOS |  | 已改为 Keychain 持久化 access/refresh token |
| AUTH-IOS-002 | 启动恢复会话（restoreSession） | P0 | DONE | iOS |  | 已完成启动恢复与失效清理 |
| AUTH-IOS-003 | 401 自动 refresh + 请求重放 | P0 | DONE | iOS |  | 已加 refresh 互斥门控，避免并发重复 refresh |
| AUTH-IOS-004 | 手机号验证码登录 UI 与接线 | P0 | DONE | iOS |  | 已支持登录模式切换、发码冷却、短信登录提交 |
| AUTH-IOS-005 | UI 自动化：重启恢复与失效回登录 | P0 | DONE | iOS |  | `RaverMVPUITests` 两条关键用例已通过（iPhone 17 Simulator） |

---

## 9. 重要日志记录区（执行中持续追加）

> 这里记录“关键排障信息”，不是普通日报。

### 9.1 关键运行日志模板

```
[时间] 2026-04-21 20:35
[环境] dev/staging/prod
[模块] server-auth / web-auth / ios-auth
[场景] login / refresh / logout / restore session
[输入摘要] user=***, device=ios-sim-01
[结果] success/fail
[错误码] AUTH_TOKEN_EXPIRED
[关键日志] ...
[结论] ...
[后续动作] ...
```

### 9.2 故障记录模板

| 时间 | 故障现象 | 影响范围 | 根因 | 临时止血 | 永久修复 | 关联PR |
|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |

### 9.3 本期关键日志（已记录）

| 时间 | 场景 | 结果 | 关键日志/现象 | 结论 | 后续动作 |
|---|---|---|---|---|---|
| 2026-04-21 17:24 | iOS 构建（`xcodeproj`） | FAIL | `framework 'MJExtension' not found` | 不是登录态代码错误，而是构建入口错误（未走 Pods workspace） | 统一改为 `.xcworkspace` 构建 |
| 2026-04-21 17:27 | iOS 构建（`xcworkspace`） | SUCCESS | `xcodebuild -workspace ... -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build` 返回 `BUILD SUCCEEDED` | 登录态改造代码可正常参与完整构建 | 继续执行联调与冒烟测试 |
| 2026-04-21 17:32 | 数据库迁移（Auth） | SUCCESS | `prisma migrate deploy` 应用两条未执行迁移，`migrate status` 显示 `Database schema is up to date` | 本地开发库 schema 与代码一致 | 进入接口级冒烟与端到端联调 |
| 2026-04-21 17:33 | 后端 Auth 冒烟 | SUCCESS | `POST /v1/auth/register(201)`、`POST /v1/auth/refresh(200)`、`POST /v1/auth/logout(200)`、`POST /v1/auth/refresh(401)`；短信 `send(201)`、错误码登录 `401` | refresh 轮换和登出失效行为符合预期 | 补充自动化测试并接入限流/审计 |
| 2026-04-21 17:33 | Token TTL 配置核验 | WARNING | 冒烟响应中 `accessTokenExpiresIn=604800`（7 天） | 当前环境仍走旧 `JWT_EXPIRES_IN` 回退，未达到冻结需求 15 分钟 | 在 `.env` 或部署环境配置 `ACCESS_TOKEN_EXPIRES_IN=15m` 与 `REFRESH_TOKEN_EXPIRES_IN=30d` 后复测 |
| 2026-04-21 17:35 | Token TTL 覆核（配置生效性） | SUCCESS | 临时实例 `PORT=3902 ACCESS_TOKEN_EXPIRES_IN=15m REFRESH_TOKEN_EXPIRES_IN=30d` 下 `POST /v1/auth/register` 返回 `accessTokenExpiresIn=900` | 代码与配置路径正确，15 分钟策略可生效 | 将同样配置落到目标环境并纳入发布检查项 |
| 2026-04-21 17:41 | 登录限流冒烟 | SUCCESS | 同一账号连续错误登录：第 `1/10` 次返回 `401`，第 `11` 次返回 `429` | 登录限流策略已生效，能够拦截爆破尝试 | 为 register 场景补自动化用例 |
| 2026-04-21 17:42 | Auth 回归冒烟（限流改造后） | SUCCESS | `register(201) -> refresh(200) -> logout(200) -> refresh(401)` | 限流与审计日志改造未破坏原有会话链路 | 进入自动化测试与发布前联调 |
| 2026-04-21 17:44 | 注册限流冒烟 | SUCCESS | 同一账号注册请求：第 `1` 次 `201`、第 `10` 次 `409`（用户已存在）、第 `11` 次 `429` | 注册入口限流策略已生效 | 补 register 限流自动化测试用例 |
| 2026-04-21 17:49 | Auth 自动化脚本冒烟 | SUCCESS | 新增 `pnpm auth:smoke`，在 `http://127.0.0.1:3906/v1` 返回：`register(201)`、`refresh(200)`、`logout(200)`、`refresh-after-logout(401)` | 登录态核心流程可脚本化回归验证 | 在 CI/发布前检查中纳入该脚本 |
| 2026-04-21 17:50 | 阿里云短信联调前置检查 | BLOCKED | 当前 `.env` 未配置 `ALIYUN_SMS_ACCESS_KEY_ID/SECRET/SIGN_NAME/TEMPLATE_CODE`，`AUTH_SMS_PROVIDER=mock` | 真实收码联调前置条件未满足 | 补齐阿里云短信参数与测试手机号后执行真机联调 |
| 2026-04-21 22:50 | 临时短信替代路径验证 | SUCCESS | `POST /v1/auth/sms/send` 返回 `201`，响应包含 `debugCode` 与 `debugProvider=mock`（非生产） | 在不等待阿里云报备完成前可稳定联调短信登录链路 | 报备完成后关闭 debug 返回并切回 aliyun provider |
| 2026-04-22 00:02 | Auth 集成测试脚本 | SUCCESS | 新增 `pnpm auth:integration`，实跑结果：`account-session`、`login-rate-limit`、`register-rate-limit`、`sms-flow` 全部通过 | auth 核心链路具备可重复回归能力 | 接入 CI，并在切回 aliyun 后补充真短信场景 |
| 2026-04-22 09:10 | CI 集成测试守卫 | SUCCESS | 新增 `.github/workflows/auth-integration-guard.yml`：`Postgres -> migrate deploy -> build -> health check -> pnpm auth:integration` | auth 集成链路已具备 PR/Push 自动回归能力 | 观察首轮 CI 运行并根据耗时优化 |
| 2026-04-22 09:10 | iOS UI 自动化（会话恢复/失效回登录） | SUCCESS | `xcodebuild -workspace ... -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RaverMVPUITests test` 返回 `TEST SUCCEEDED` | 登录态关键用户路径可被自动化回归验证 | 继续补充 401 自动 refresh UI 场景 |

---

## 10. 方案决策日志（必须维护）

| 日期 | 决策主题 | 备选项 | 最终选择 | 决策理由 | 影响范围 |
|---|---|---|---|---|---|
| 2026-04-21 | Token 模型 | 单 JWT / 双 token | 双 token | 支持静默续期与会话撤销 | 全端 |
| 2026-04-21 | 登录方式 | 账号密码 / 第三方 / 手机验证码 | 账号密码 + 阿里云短信手机号登录 | 先满足主登录场景，第三方后置 | 后端+iOS |
| 2026-04-21 | 本期范围 | 后端+Web+iOS / 后端+iOS | 后端+iOS | Web 为后台，二期再做 | 研发排期 |
| 2026-04-21 | iOS Token 持久化 | Keychain / UserDefaults | Keychain | 系统级安全存储，重启不丢失 | iOS |
| 2026-04-21 | Token 生命周期 | access 15m + refresh 30d / 单 token 7d | access 15m + refresh 30d | 兼顾安全与体验 | 后端+iOS |
| 2026-04-21 | 短信临时替代方案 | 暂停短信登录 / mock日志查码 / mock响应回传验证码 | mock响应回传验证码（非生产） | 不阻塞联调，且无需改接口即可回切阿里云 | 后端+iOS |

---

## 11. 开发执行指令参考

> 以下是推荐流程命令，按你当前仓库结构。

### 11.1 后端

```bash
cd /Users/blackie/Projects/raver/server
pnpm install
pnpm prisma:migrate --name auth_refresh_tokens
pnpm prisma:generate
pnpm dev
pnpm auth:smoke
pnpm auth:integration
```

临时替代（联调用）：
```bash
AUTH_SMS_PROVIDER=mock
AUTH_SMS_DEBUG_RETURN_CODE=true
AUTH_SMS_DEBUG_PHONE_ALLOWLIST=
```

切回阿里云（报备完成后）：
```bash
AUTH_SMS_PROVIDER=aliyun
AUTH_SMS_DEBUG_RETURN_CODE=false
ALIYUN_SMS_ACCESS_KEY_ID=...
ALIYUN_SMS_ACCESS_KEY_SECRET=...
ALIYUN_SMS_SIGN_NAME=...
ALIYUN_SMS_TEMPLATE_CODE_LOGIN=...
```

### 11.2 Web（二期）

```bash
cd /Users/blackie/Projects/raver/web
pnpm install
pnpm dev
```

### 11.3 iOS

```bash
cd /Users/blackie/Projects/raver/mobile/ios/RaverMVP
xcodegen generate
pod install
open /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build
```

---

## 12. 风险清单与应对

1. 风险：双栈接口并存导致行为不一致
- 应对：统一以 `/v1/auth` 为权威，`/api/auth` 仅兼容

2. 风险：refresh 并发导致 token 冲突
- 应对：客户端 refresh 互斥 + 服务端 rotation 原子化

3. 风险：短信服务商可用性与到达率不稳定
- 应对：发送重试、通道监控、失败降级提示、预留 provider 抽象层

4. 风险：iOS 仍处于 mock 环境误测
- 应对：启动流程中显式展示 runtime mode 与 baseURL

---

## 13. Definition of Done（本方案完成判定）

以下全部满足，才算登录态能力完成：

1. 本期目标端（后端+iOS）支持重启后恢复登录态。
2. access token 过期可自动刷新。
3. refresh token 可轮换、可失效、可登出撤销。
4. 关键鉴权接口有自动化测试。
5. 线上可见登录成功率与 refresh 成功率。
6. 本文档第 8/9/10 章有完整执行记录。

---

## 14. 下一步建议（已确认后执行）

1. 在目标数据库执行 migration，并完成 `refresh/sms` 接口联调验收。
2. 将 `pnpm auth:smoke` 与 `pnpm auth:integration` 纳入日常联调与发布前检查。
3. 报备期内维持 `mock+debugCode` 联调路径，持续推进 iOS/后端功能。
4. 报备完成后切回 `aliyun` 并做真实手机号收码冒烟。
5. 补充 iOS 端 UI 自动化第 3 条用例（401 自动 refresh + 请求重放）。
6. Web 暂缓，待你明确排期后再启动 Phase 3。
