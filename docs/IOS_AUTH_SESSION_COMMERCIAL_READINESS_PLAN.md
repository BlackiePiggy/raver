# iOS 登录态商用稳定性补齐计划

> Status: Draft  
> Owner: iOS / Backend / QA / Operations  
> Created: 2026-05-22  
> Scope: `mobile/ios/RaverMVP/`, `server/src/routes/bff.routes.ts`, `server/src/utils/auth.ts`, auth environment, QA runbooks  
> Related: `docs/AUTH_SESSION_COMMERCIALIZATION_PLAN.md`, `docs/AUTH_LOGIN_STATE_FULL_GUIDE.md`

## 1. 目标

本计划聚焦一个商用体验目标：

在用户已登录、账号未被停用、没有被主动踢下线、refresh token 未到期、Keychain 未损坏的正常情况下，iOS App 运行期间不应因为 access token 过期而退出登录或要求用户重新登录。

换句话说：

- access token 过期是正常事件，不是登录失效。
- 业务请求收到 401 时，应先静默 refresh 并重试。
- refresh 成功后必须同步本地 Keychain 和内存 session。
- 只有 refresh token 失效、会话被撤销、账号停用、用户主动退出等硬失败，才进入重新登录。

## 1.1 本轮推进状态

2026-05-22 已完成首轮落地：

- 活动上传/编辑的后端事务已减少逐条写入，降低 Prisma interactive transaction 5 秒超时导致 500 的概率。
- `LiveWebFeatureService.updateEvent` 所在链路已补齐 401 refresh + retry。
- `LiveSocialService` 与 `LiveWebFeatureService` 已共用 process-wide `AppAuthRefreshGate`，避免并发 refresh 互相踩旧 refresh token。
- `ShareLinkService` 与 `LiveVirtualAssetRepository` 已补齐 401 refresh + retry，不再把 access token 过期直接当作登录失效。
- 新增 `scripts/check-ios-auth-session-guardrails.sh`，用于阻止未来页面直接读取 token、手写 Authorization、直接发布 session expired、绕过受控网络层。
- 启动恢复、回前台恢复已区分弱网/500 与认证硬失败；弱网不清登录态。
- iOS 已接入后端 `accessTokenExpiresIn`，记录本地 `accessTokenExpiresAt`，回前台时距过期不足 2 分钟才主动 refresh。
- iOS 已监听网络从离线恢复到在线，恢复后会静默补一次 session refresh。
- `SessionTokenStore` 已增加运行期缓存与 Keychain 写失败日志，降低 refresh 成功后因持久化抖动导致的误退出风险。
- 已抽出 `AuthenticatedRequestRunner`，`LiveSocialService`、`LiveWebFeatureService`、`ShareLinkService`、`LiveVirtualAssetRepository` 的 JSON 请求已共享同一套 401 refresh + retry 内核；`LiveSocialService` 与 `LiveWebFeatureService` 的 multipart 上传也已接入同一 runner。
- Auth session guardrail 已接入 `.github/workflows/mvvm-coordinator-guard.yml`，后续新增页面会被 CI 约束。
- 已新增 `RaverMVPTests` 单元测试 target，并覆盖 `AuthenticatedRequestRunner` 的成功请求、401 refresh + retry、弱网 refresh 失败不清登录态、账号停用硬退出、并发 401 只 refresh 一次。
- 活动上传/编辑提交前已增加用户动作级 auth preflight：access token 接近过期时先通过同一 refresh gate 静默续期，再进入图片上传与 create/update 请求。
- 后端已新增 auth env lint，并接入服务启动与 auth session preflight：production 会拒绝默认/缺失 token secret，强制 iOS refresh token TTL 保持 30 天。

## 2. 当前状态

已具备的基础能力：

- iOS 使用 `/v1/auth/*` 主协议。
- iOS 使用 access token + refresh token 双 token。
- access token 与 refresh token 存入 Keychain。
- `LiveSocialService` 已具备 401 后 refresh + 请求重放能力。
- 后端 `/v1/auth/refresh` 已执行 refresh token 轮换，旧 refresh token 会 revoke。
- 后端区分 iOS 与 Web Admin 会话：iOS refresh token 目标为 30 天，不使用后台 30 分钟 idle timeout。
- 设置页已有设备会话相关能力基础。

近期已补齐的关键点：

- `LiveWebFeatureService` 已与 `LiveSocialService` 一样具备 401 后 refresh + 请求重放能力。
- refresh 成功后已通过 `.raverSessionRefreshed` 同步 `AppState.session`，避免 Keychain 已更新但内存 session 仍停留在旧 token。
- 活动上传/编辑相关后端事务已减少长事务和 500，避免用户误以为提交导致登录异常。

## 3. 当前差距

### 3.1 客户端统一续期链路未完全产品化

风险：

- 不同 service 自己实现 token/401 处理，容易出现某条业务链路没有 refresh。
- 某些上传、导入、内容提交、分享等接口如果绕过统一 request 层，仍可能直接把 401 当作登录失效。
- refresh 成功后如果只更新 Keychain、不更新内存 session，部分 UI 或后续能力可能仍认为会话旧。

商用要求：

- 所有需要登录的 iOS 网络请求必须经过统一 auth request pipeline。
- pipeline 必须支持：添加 access token、401 判断、refresh gate、请求重放、错误码分流、session 同步。
- 禁止业务模块自己直接把 401 转成 `.raverSessionExpired`。

### 3.2 缺少前台恢复和运行中主动续期策略

风险：

- 现在多数续期依赖请求遇到 401 后被动触发。
- 用户停留在编辑页面很久后提交，第一跳就可能遇到 access 过期。
- 弱网时 refresh 和业务请求重试叠加，用户体验容易抖动。

商用要求：

- App 启动、从后台回前台、网络恢复时，如果 session 存在，应主动检查并刷新。
- 根据 `accessTokenExpiresIn` 或本地记录的签发/刷新时间，在过期前主动 refresh。
- 主动 refresh 失败不应立即打断用户，除非后端明确返回会话撤销、账号停用、refresh 过期等硬失败。

### 3.3 refresh 轮换边界未完成真机验证

风险：

- refresh token 每次轮换，旧 token 立即失效。
- 如果刷新成功但本地保存新 refresh token 失败，下一次 refresh 会用旧 token，导致用户被迫重新登录。
- 如果多个 service 并发 refresh，可能出现旧 refresh token 被重复使用。

商用要求：

- 全 App 共用一个 refresh gate。
- refresh 成功后，必须原子化更新 access token、refresh token、内存 session。
- refresh 成功但本地保存失败时，必须暴露可观测错误，并避免静默进入不可恢复状态。

### 3.4 错误语义和用户体验还需收口

风险：

- `AUTH_REFRESH_TOKEN_INVALID_OR_EXPIRED`、`AUTH_SESSION_REVOKED`、`AUTH_ACCOUNT_INACTIVE`、普通 access 过期可能被混成同一个“登录失效”。
- 普通网络失败可能被误判为登录失败。
- 用户无法分清是网络问题、服务器问题、还是账号真的需要重新登录。

商用要求：

- access token 过期：用户无感。
- refresh token 过期：提示登录已过期。
- 当前设备被撤销：提示当前设备已被退出登录。
- 账号停用/删除：提示账号不可用。
- 网络失败：提示网络异常，保留登录态。
- 服务器 500：提示服务异常，保留登录态。

### 3.5 缺少生产环境门禁

风险：

- dev/staging/prod 的 `ACCESS_TOKEN_EXPIRES_IN`、`REFRESH_TOKEN_EXPIRES_IN` 不一致。
- 生产环境可能误用默认 JWT secret。
- auth 相关 env 缺失时服务仍启动，导致线上行为不可预测。

商用要求：

- production 必须强制校验 auth env。
- `ACCESS_TOKEN_EXPIRES_IN=15m`、`REFRESH_TOKEN_EXPIRES_IN=30d` 等关键 TTL 必须在部署前确认。
- 禁止生产使用默认 secret。
- CI 或部署脚本必须包含 auth env lint。

### 3.6 缺少可观测性和验收数据

风险：

- 用户反馈“突然退出登录”时，无法判断是 access 过期误判、refresh 失败、会话撤销、账号异常、Keychain 问题还是服务端 500。

商用要求：

- 服务端记录 login/refresh/logout/session revoke 的结构化审计。
- iOS 记录本地 auth lifecycle breadcrumb，不记录 token 明文。
- 线上监控 refresh 成功率、refresh 失败原因、401 重试成功率、非预期 session expired 次数。

## 4. 目标架构

### 4.1 iOS Auth Request Pipeline

所有登录态请求必须走同一个流程：

1. 构造请求。
2. 如果有 access token，添加 `Authorization: Bearer <token>`。
3. 发送请求。
4. 如果不是 401，正常处理。
5. 如果是 401：
   - 如果错误码是账号停用或会话撤销，进入明确退出流程。
   - 否则调用 refresh gate。
6. refresh gate：
   - 如果已有 refresh 在进行，等待同一个任务。
   - 否则用 Keychain 中 refresh token 调 `/v1/auth/refresh`。
   - 成功后保存新的 access/refresh token。
   - 同步 `AppState.session`。
7. 用新 access token 重放原请求一次。
8. 重放仍 401 才按错误码处理。

### 4.2 Session 状态定义

建议把客户端状态拆清楚：

- `authenticated`: 已登录且可请求。
- `refreshing`: 正在刷新，不展示退出。
- `recoverableNetworkError`: 网络异常，保留登录态。
- `expired`: refresh token 到期，需要登录。
- `revoked`: 当前设备被撤销。
- `accountInactive`: 账号停用或删除。

## 5. 实施计划

### Phase 1：客户端统一续期收口

目标：消除“某条业务链路漏 refresh”的问题。

任务：

- [x] 抽象 process-wide `AppAuthRefreshGate`，先消除并发 refresh token 轮换风险。
- [x] `LiveSocialService` 改为使用统一 refresh gate。
- [x] `LiveWebFeatureService` 改为使用统一 refresh gate，并覆盖活动编辑、上传、导入等链路。
- [x] `ShareLinkService`、`LiveVirtualAssetRepository` 接入 401 refresh + retry；通知、IM bootstrap 暂无新增漏口，后续由静态检查兜底。
- [x] 禁止普通业务模块直接发布 `.raverSessionExpired`；当前仅 auth-owned 网络层和 `AppState` 保留该入口。
- [x] 增加静态检查脚本，扫描 `URLSession.data`、`SessionTokenStore.shared.token`、`.raverSessionExpired` 的非白名单使用。
- [x] 抽象 `AuthenticatedRequestRunner`，收敛 Social、WebFeature、ShareLink、VirtualAsset 的 JSON 请求，并覆盖 Social/WebFeature multipart 上传。
- [x] 为 `AuthenticatedRequestRunner` 补充核心单元测试，覆盖 refresh/retry、弱网、硬失败、并发 gate。
- [ ] 进一步抽象完整 `AuthenticatedHTTPClient` 或 `AuthRequestPipeline`，把请求构造、错误解码、响应 decode 也继续平台化。

验收：

- access token 过期后，活动编辑、活动创建、图片上传、DJ 编辑、Set 编辑、打卡、收藏、分享等核心路径均不退出登录。

### Phase 2：主动续期

目标：减少用户在提交时撞上 401 的概率。

任务：

- [x] 登录/refresh 成功后记录 `accessTokenExpiresAt`。
- [x] App 启动恢复后立即 refresh 并更新 session。
- [x] App 从后台回前台时，如果 access token 距离过期不足 2 分钟，主动 refresh。
- [x] 网络恢复时，如果上次 refresh 因网络失败跳过，后台静默补一次。
- [x] 长时间编辑页面提交前，若 access token 接近过期，先 refresh 再提交。

验收：

- 用户在活动编辑页停留 30 分钟后提交，不应出现“请重新登录”。
- App 前后台切换多次后，下一次业务请求应使用新 token。

### Phase 3：refresh 轮换可靠性

目标：避免 refresh 成功但本地状态不一致。

任务：

- [x] refresh 成功后更新 access token、refresh token、access 过期时间、内存 session。
- [x] 如果 Keychain 写入失败，保留进程内最新 session，并记录错误日志。
- [x] 所有当前 auth-owned 网络层 refresh 共用同一个 process-wide gate。
- [ ] 记录 refresh sequence，用于排查并发 refresh。
- [x] refresh 失败时区分网络失败和认证失败：网络失败保留登录态，认证失败才退出。

验收：

- 并发 10 个请求同时收到 401，只发生一次 `/v1/auth/refresh`。
- refresh 成功后所有请求使用同一个新 access token 重试。

### Phase 4：服务端和环境门禁

目标：线上配置不会让客户端“无端失效”。

任务：

- [x] production 启动时强制检查 `ACCESS_TOKEN_SECRET`。
- [x] production 禁止默认 `JWT_SECRET`。
- [x] production 强制确认 `REFRESH_TOKEN_EXPIRES_IN=30d` 或明确商用配置。
- [x] refresh 成功后更新 `lastUsedAt`，便于排查和设备列表展示。
- [x] `/v1/auth/refresh` 返回稳定 `code`，所有失败路径覆盖。
- [x] 加入 auth env lint 到 CI 或部署脚本。

验收：

- 部署前可以自动输出 auth TTL 和 provider 配置摘要。
- 缺少关键 auth env 时生产服务拒绝启动。

### Phase 5：可观测性

目标：线上能判断为什么用户退出登录。

任务：

- [x] 后端新增或完善 auth audit log：当前已覆盖 login、refresh 及其失败/blocked 分支，数据同时输出 console、内存 metrics、`auth_audit_logs` 表；logout、logout-all、session revoke 继续补齐。
- [x] auth audit 已记录 `userId`、`clientType`、`refreshTokenId/session chain`、`outcome`、`reasonCode`、设备与版本元数据；当前未单独记录 `latencyMs`，作为下一步补充项。
- [x] iOS 已增加本地 auth breadcrumb：request 401、refresh start/success/failure、retry 完成、session expired reason、bootstrap/proactive refresh、network restored、keychain persistence issue。
- [x] 线上已具备 refresh 成功率、refresh 失败率、hard expiry rate、errorCode/clientType 分布等基础 metrics，并挂入 admin status 与独立 admin auth metrics 接口。
- [ ] 增加异常告警：iOS refresh failure rate 超阈值、401 retry failure rate 超阈值。

验收：

- 用户反馈“突然重新登录”时，可以从日志判断确切原因。

### Phase 6：真机与弱网回归

目标：用真实环境验证稳定性。

任务：

- [ ] 真机验证 Keychain：杀进程、重启、系统重启、App 更新后 session 恢复。
- [ ] 弱网验证：业务请求 401 后 refresh 成功重试。
- [ ] 弱网验证：refresh 网络失败时不清登录态。
- [ ] 并发验证：多个页面同时触发 401，只 refresh 一次。
- [ ] 长编辑验证：活动编辑页停留超过 access TTL 后提交成功。
- [ ] 图片上传验证：multipart 上传 401 后 refresh 重试成功。
- [ ] 账号停用验证：正确退出并展示账号不可用。
- [ ] 当前设备撤销验证：正确退出并展示设备已退出。

验收：

- QA 矩阵全部通过后，才可标记为商用稳定。

## 6. 验收矩阵

| 场景 | 预期 | 是否必须 |
| --- | --- | --- |
| access token 过期后打开首页 | 自动 refresh，不退出 | 必须 |
| access token 过期后编辑活动提交 | 自动 refresh 并重试 PATCH，不退出 | 必须 |
| access token 过期后上传图片 | 自动 refresh 并重试 upload，不退出 | 必须 |
| 多请求同时 401 | 只 refresh 一次，其余等待 | 必须 |
| refresh token 过期 | 退出登录，提示登录已过期 | 必须 |
| 当前设备被撤销 | 退出登录，提示当前设备已被退出 | 必须 |
| 账号停用 | 退出登录，提示账号不可用 | 必须 |
| 网络断开导致 refresh 失败 | 保留登录态，提示网络异常 | 必须 |
| 服务端 500 | 保留登录态，提示服务异常 | 必须 |
| App 重启 | 通过 refresh 恢复 session | 必须 |
| App 更新后 | Keychain session 可恢复 | 必须 |
| 真机后台 1 小时后回前台 | 主动 refresh，不退出 | 必须 |

## 7. 商用完成标准

## 7.1 未来页面接入守则

新增页面、Repository、Service 时必须遵守：

- 所有需要登录的请求只能通过统一 `AuthRequestPipeline` 或已接入该 pipeline 的 repository/service 发出。
- 页面层不得直接读取 `SessionTokenStore.shared.token` 或 `SessionTokenStore.shared.refreshToken`。
- 页面层不得手写 `Authorization: Bearer ...`。
- 页面层不得直接调用 `URLSession.shared.data` 发业务请求。
- 业务模块不得直接发布 `.raverSessionExpired`；只有 auth pipeline 或 `AppState` 的退出入口可以触发。
- 普通 401 不等于登录失效；必须先 refresh + retry。
- refresh 网络失败、业务 500、普通网络断开不得清理登录态。
- 新增上传、导入、长耗时提交能力时，必须验证 access token 过期后的重试行为。
- 新增 service 时必须补充到静态检查白名单或接入统一 pipeline，否则 CI 应失败。

工程守卫：

- `scripts/check-ios-auth-session-guardrails.sh` 负责扫描高风险写法。
- 白名单只能用于 auth pipeline、session store、mock/test 或明确不需要登录的底层工具。
- 新增白名单必须在 PR 说明中解释原因。

满足以下条件才算达到本专项商用水平：

- [x] 当前扫描范围内的 iOS 登录态请求已收口到 auth-owned 网络层或明确豁免。
- [x] 当前扫描范围内的 401 已先 refresh + retry，只有硬失败才退出。
- [x] refresh 成功后 Keychain 和 `AppState.session` 同步。
- [x] 前台恢复和长时间运行具备主动续期。
- [x] 已覆盖当前改造链路：网络失败和服务端 500 不会清登录态。
- [x] dev/staging/prod auth env 通过门禁。
- [x] 后端 auth audit 已可查询：`/admin/auth-audit-logs`、`/admin/auth-metrics`、`/admin/status`。
- [x] iOS 本地 auth breadcrumb 已可用于排查最近 auth 生命周期事件。
- [x] 静态检查脚本已接入本地 preflight 或 CI。
- [ ] 真机弱网、杀进程、重启、升级、长编辑、上传场景全部通过。

## 8. 优先级建议

第一优先级：

1. 统一 iOS auth request pipeline。
2. 前台恢复主动续期。
3. refresh 网络失败不清登录态。
4. 真机验证活动编辑、图片上传、长时间编辑。

第二优先级：

1. auth env 生产门禁。
2. refresh audit 落库。
3. iOS breadcrumb。
4. 静态检查脚本。

第三优先级：

1. 用户侧设备会话体验优化。
2. 修改密码后是否退出其他设备的交互。
3. 后台审计页面和运营筛选。

## 9. 明确边界

以下情况不承诺保持登录：

- 用户主动退出。
- 管理员或用户自己撤销当前设备。
- refresh token 到期。
- 账号被删除、停用、封禁登录。
- Keychain 数据被系统、用户、迁移或安全策略清除。
- 设备时间、系统环境、证书或网络被严重篡改，导致认证无法可信完成。

其余普通 access token 过期、前后台切换、弱网、服务端短暂 500，都不应导致用户被退出登录。
