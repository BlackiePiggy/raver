# Raver Phase 6 Admin / Operations Inventory

> Status: Active
> Owner: Backend / Web Admin / Operations
> Created: 2026-05-13
> Applies To: `server/src/routes/*admin*`、`web/src/app/admin/`、`web/src/lib/api/*admin*`、ops jobs/scripts
> Related: `docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md`、`docs/RAVER_BACKEND_MODULE_OWNERSHIP.md`、`docs/DATABASE_BACKUP_GATEKEEPER.md`、`docs/adr/0006-admin-console-over-public-web-first.md`

## 1. Phase 6 Scope

Phase 6 的目标不是新增后台功能，而是把现有运营能力从“散落页面 + 散落 API + 散落脚本”收束成一个商用级 Admin / Operations 系统。

本阶段坚持四条边界：

- 不改 App 核心用户链路。
- 不新增推荐、商业化、举报审核扩展、内容策略等外扩需求。
- 不把 OpenIM 历史后台能力扩展为当前 IM 主线。
- 任何 schema migration、运营数据迁移、批量修复、projection rebuild、snapshot rebuild、IM sync apply 之前，必须先按 `DATABASE_BACKUP_GATEKEEPER.md` 备份并验证数据库。

本文件是 Phase 6 P0 清点文档。当前批次只做 inventory / ownership / migration order，不做 API 迁移、不做数据库变更、不做后台页面重构。

## 2. Current Problem

现有后台能力已经具备平台雏形，但工程边界不清晰：

- Admin API 分散在 `/api/admin/*`、`/v1/notification-center/admin/*`、`/v2/admin/*`、`/v1/admin-like` 资源路径中。
- 权限校验有 `authorize('admin')`、`authorize('admin', 'operator')` 和局部 helper 混用。
- Web Admin 页面各自持有 API client，没有统一 Admin shell / Admin API client。
- Notification、Pre-registration、Check-in projection、VirtualAsset grant、IM legacy ops 的运营能力没有统一 ownership。
- 敏感操作缺少统一审计模型，当前只能依赖业务表或日志追溯。
- Worker / projection / notification 状态有局部查询能力，但没有形成一个运营状态入口。

所以 Phase 6 的核心不是“做更多后台页面”，而是先建立运营系统边界：统一入口、统一权限、统一审计、统一状态聚合。

## 3. Target Ownership Model

Phase 6 目标采用 `admin` module 作为运营聚合层，但不吞并领域业务规则。

```text
server/src/modules/admin/
  admin.routes.ts          # /api/admin/v1 聚合入口
  admin-auth.policy.ts     # admin/operator 权限与后续 RBAC
  admin-audit.service.ts   # 审计写入，后续需要 schema
  admin-status.service.ts  # 跨 worker / projection / notification 状态聚合
  index.ts

server/src/modules/<domain>/
  # 领域仍拥有自己的业务规则
  # admin module 只通过领域 service / ops facade 调用
```

目标 ownership：

| Area | Owner | 职责 | 不负责 |
| --- | --- | --- | --- |
| `admin-shell` | `modules/admin` + `web/src/app/admin` | 统一后台入口、导航、角色态、状态聚合 | 不承载领域业务规则 |
| `notification-ops` | `modules/notifications` | 通知状态、配置、模板、测试发布、delivery 查询 | 不做通用审核系统 |
| `pre-registration-ops` | `modules/pre-registrations` | 预报名列表、批次、决策、通知入队 | 不扩展成 CRM |
| `checkin-ops` | `modules/checkins` | projection freshness、worker 状态、reproject / rebuild runbook | 不绕过备份门禁执行数据动作 |
| `virtual-asset-ops` | `modules/virtual-assets` | 资产发放、发放审计 | 不新增商业化玩法 |
| `im-ops-current` | `modules/im` | Tencent IM bootstrap / sync / group ops 状态 | 不接入 OpenIM 新能力 |
| `im-ops-legacy` | `services/openim` + legacy docs | OpenIM 历史数据参考、迁移清理 | 不作为当前后台产品能力 |
| `content-ops` | `modules/feed/events/music` | 后续内容状态、基础管理、只读诊断 | 不在 Phase 6 P0/P1 扩展内容审核 |

## 4. Current Admin Route Inventory

| Domain | Current Endpoint | Mount | Role | Current Owner | Risk | Target |
| --- | --- | --- | --- | --- | --- | --- |
| Notification | `POST /admin/major-news/publish` | `/v1/notification-center` | `admin` | `notification-center.routes.ts` | 敏感发布操作，无统一审计 | `/api/admin/v1/notifications/major-news/publish` facade |
| Notification | `POST /admin/publish-test` | `/v1/notification-center` | `admin` | `notification-center.routes.ts` | 测试发布影响真实 delivery | `/api/admin/v1/notifications/publish-test` facade |
| Notification | `GET /admin/status` | `/v1/notification-center` | `admin` | `notification-center.routes.ts` | 运营状态入口孤立 | `/api/admin/v1/notifications/status` |
| Notification | `GET /admin/deliveries` | `/v1/notification-center` | `admin` | `notification-center.routes.ts` | 查询能力未纳入 Admin shell | `/api/admin/v1/notifications/deliveries` |
| Notification | `GET /admin/config` / `PUT /admin/config` | `/v1/notification-center` | `admin` | `notification-center.routes.ts` | 配置变更缺统一审计 | `/api/admin/v1/notifications/config` |
| Notification | `GET /admin/templates` / `PUT /admin/templates` | `/v1/notification-center` | `admin` | `notification-center.routes.ts` | 模板变更缺统一审计 | `/api/admin/v1/notifications/templates` |
| Pre-registration | `GET /admin/pre-registrations` | `/api` | `admin/operator` | `pre-registration.routes.ts` | 与 notification admin base 不一致 | `/api/admin/v1/pre-registrations` |
| Pre-registration | `GET/POST /admin/pre-registration-batches` | `/api` | `admin/operator` | `pre-registration.routes.ts` | 批次创建缺统一审计 | `/api/admin/v1/pre-registration-batches` |
| Pre-registration | `GET /admin/pre-registration-batches/:batchId/results` | `/api` | `admin/operator` | `pre-registration.routes.ts` | 批次结果入口孤立 | `/api/admin/v1/pre-registration-batches/:batchId/results` |
| Pre-registration | `POST /admin/pre-registration-batches/:batchId/decisions` | `/api` | `admin/operator` | `pre-registration.routes.ts` | 批量决策敏感，需审计 | `/api/admin/v1/pre-registration-batches/:batchId/decisions` |
| Pre-registration | `POST /admin/pre-registration-notifications` | `/api` | `admin/operator` | `pre-registration.routes.ts` | 通知入队影响用户触达 | `/api/admin/v1/pre-registration-notifications` |
| Check-in Ops | `GET /admin/checkins/projection/status` | `/v2` | `admin/operator` | `checkins-v2.routes.ts` | 使用局部 `requireAdminOrOperator`，base 分散 | `/api/admin/v1/checkins/projection/status` |
| Virtual Assets | `POST /admin/virtual-assets/grants` | `/v1` | `admin/operator` | `virtual-asset.routes.ts` | 资产发放敏感，需审计 | `/api/admin/v1/virtual-assets/grants` |
| Music Content | `PUT /api/djs/:id` / `DELETE /api/djs/:id` | `/api/djs` | `admin` | `dj.routes.ts` | 内容管理散落在 public resource route | P2 再评估是否纳入 content ops |
| Music Content | `POST /api/djs` / `POST /api/djs/batch` | `/api/djs` | `admin/user` | `dj.routes.ts` | user/admin 混合写入口，不适合作为 Admin P1 | 保持原状，后续内容域治理 |
| BFF Admin Checks | 多处 `authReq.user?.role === 'admin'` | `/v1`、`/v1/web` | `admin` | `bff.routes.ts` / `bff.web.routes.ts` | 领域内权限散落 | 不在 P0/P1 迁移，后续按领域拆 |
| OpenIM Legacy Admin | Web client references `/v1/openim/admin/*` | `/v1` expected | unknown / not found in current backend scan | `web/src/lib/api/openim-admin.ts` | 当前后端未发现 active route；易误认为 current IM ops | 标记 legacy，不扩展 |

## 5. Web Admin Inventory

| Page / Client | Current Path | API Base | Role Check | Current Issue | Target |
| --- | --- | --- | --- | --- | --- |
| Notification Center Admin Page | `web/src/app/admin/notification-center/page.tsx` | `web/src/lib/api/notification-center-admin.ts` -> `/v1/notification-center/admin/*` | page checks `user?.role === 'admin'` | 页面自管权限和状态 | 接入 Admin shell，API 迁到 `/api/admin/v1/notifications/*` facade |
| Pre-registration Admin Page | `web/src/app/admin/pre-registrations/page.tsx` | `web/src/lib/api/pre-registration.ts` -> `/api/admin/*` | page checks `admin/operator` | 与 notification admin API base 不一致 | 接入 Admin shell，API 迁到 `/api/admin/v1/pre-registrations/*` facade |
| OpenIM Admin Client | `web/src/lib/api/openim-admin.ts` | `/v1/openim/admin/*` | token only in client | 后端未发现 active current route；OpenIM 非当前主线 | 标记 legacy client，不纳入 current Admin shell |

Phase 6 P1 前不建议新增新的 admin page。先建立统一 Admin API facade 和 shared admin auth，再让现有页面切到统一 client。

## 6. Jobs / Scripts / Ops Inventory

| Area | File | Type | Data Risk | Phase 6 Handling |
| --- | --- | --- | --- | --- |
| Check-in projection | `server/src/jobs/checkin-projection/projection-worker.job.ts` | worker | Medium | 状态可接入 Admin status；执行 apply/rebuild 前必须备份 |
| Check-in status | `server/src/scripts/checkin-projection-freshness.ts` | diagnostic | Low | 可作为 Admin status 的参考能力 |
| Check-in worker run | `server/src/scripts/checkin-projection-worker-run.ts` | worker runner | Medium | 不从 Web 直接触发；先只展示状态 |
| Check-in snapshot rebuild | `server/src/scripts/checkin-rebuild-snapshots.ts` | data rebuild | High | 需要 DB backup gatekeeper |
| Check-in reproject dirty | `server/src/scripts/checkin-reproject-dirty-users.ts` | data reproject | High | 需要 DB backup gatekeeper |
| Check-in reproject user | `server/src/scripts/checkin-reproject-user.ts` | data reproject | High | 需要 DB backup gatekeeper |
| Notification outbox | `server/src/scripts/notification-outbox-run.ts` | worker runner | Medium | 可接入 notification ops 状态 |
| Notification gray verify | `server/src/scripts/notification-outbox-gray-verify.ts` | diagnostic / smoke | Low | 保留 runbook，不做后台触发按钮 |
| Notification schedulers | `server/src/scripts/notification-*-run.ts` | scheduled jobs | Medium | 统一显示 last run / config 状态 |
| Notification normalize platforms | `server/src/scripts/notification-normalize-device-platforms.ts` | data cleanup | High | 需要 DB backup gatekeeper |
| Notification regression | `server/src/scripts/notification-compat-regression.ts` | regression | Low | 保留 CLI 验证 |
| Tencent IM sync all users | `server/src/scripts/tencent-im-sync-all-users.ts` | external sync apply | High | 当前不接入 Web trigger；执行前备份并记录 |
| Tencent IM export mapping | `server/src/scripts/tencent-im-export-user-mapping.ts` | export | Low/Medium | 可保留 CLI；输出文件要清理或归档 |
| Tencent IM delete OpenIM users | `server/src/scripts/tencent-im-delete-openim-users.ts` | destructive cleanup | High | 不纳入 Phase 6 current Admin；执行前必须备份和审批 |

## 7. Phase 6 Migration Order

### P0 Inventory / Documentation

- [x] 清点现有 Admin API route、Web admin page、ops scripts。
- [x] 标记 OpenIM admin client 为 legacy / not current。
- [x] 明确 Phase 6 不做数据库动作，后续 schema / data 动作必须先备份。
- [x] 将迁移顺序写入 tracker。

### P1 Admin Route Facade

- [x] 新增 `server/src/modules/admin/README.md` 和 `index.ts`。
- [x] 新增 `/api/admin/v1` router，先做 facade，不删除旧入口。
- [x] 将 notification admin endpoints 代理到 `/api/admin/v1/notifications/*`。
- [x] 将 pre-registration admin endpoints 代理到 `/api/admin/v1/pre-registrations/*`。
- [x] 将 checkin projection status 代理到 `/api/admin/v1/checkins/projection/status`。
- [x] 将 virtual asset grant 代理到 `/api/admin/v1/virtual-assets/grants`。
- [x] `server/src/index.ts` 暴露 admin route，并在 `/api` endpoint map 中标注。
- [x] 后端 build 通过；不需要 DB backup，因为不改 schema / data。

### P2 Shared Admin Auth / Role Policy

- [x] 建立 shared admin auth helper，统一 `admin` / `operator` 判定。
- [x] 替换当前 Admin / Operations 范围内的局部 `requireAdminOrOperator` 角色判断。
- [x] 保持 `authenticate` / `authorize` 行为兼容。
- [x] Web admin client 统一到 `/api/admin/v1` facade；token/error handling 保持现有行为，不做页面重构。
- [x] Web build 通过。仅在 Web admin client 迁移时执行。

### P3 Admin Audit Log

- [x] 确认 `AdminAuditLog` schema 和历史 migration 已存在：`admin_audit_logs`。
- [x] 新增 shared audit write service，避免 admin audit 写入继续散落。
- [x] Pre-registration batch create / decision / notification enqueue 改为统一审计入口。
- [x] Notification config update / template upsert 接入审计。
- [x] Virtual asset grant 接入审计。
- [-] 本批不执行 Prisma migration，不需要 Database Change Preflight / DB backup。
- [x] 提供只读审计查询入口：`GET /api/admin/v1/audit-logs`。

### P4 Admin Status Dashboard

- [x] 建立 `/api/admin/v1/status` 聚合 endpoint。
- [x] 聚合 notification delivery、APNs config、checkin projection freshness、worker health。
- [x] 新增 Web admin status API client，先不新增页面。
- [x] Web admin shell 增加统一状态入口：`/admin`。
- [x] 不加入新运营策略，只展示已有系统状态。

### P5 Legacy / Deferred Cleanup

- [x] OpenIM admin client 标记 deprecated / legacy，不接入 current `/api/admin/v1`。
- [x] OpenIM Web 页面保留兼容入口，但页面文案标记为 Legacy / Deferred。
- [x] 内容管理类 admin 能力进入后续 content ops，不插入 Phase 6 P1/P2。
- [x] 只在 current Admin shell 稳定后再评估旧路径废弃策略。

## 8. Commercial Gap Summary

Phase 6 开始前，与商用级 Admin / Operations 的主要差距是：

- 缺统一 Admin API namespace。
- 缺统一后台权限模型和后续 RBAC 扩展点。
- 缺敏感操作审计。
- 缺统一运营状态入口。
- 旧 IM admin client 和当前 Tencent IM 主线容易混淆。
- Worker / script 还停留在工程师 CLI 视角，未形成受控运营能力。

Phase 6 的改造路径应先收边界，再补审计，再做状态聚合。不要先做新页面或新运营功能。

## 9. Validation

本 P0 批次只改文档：

- 不需要后端 build。
- 不需要 Web build。
- 不需要 iOS build。
- 不需要数据库备份。
- 需要执行 `git diff --check` 验证 markdown patch 无 whitespace error。
