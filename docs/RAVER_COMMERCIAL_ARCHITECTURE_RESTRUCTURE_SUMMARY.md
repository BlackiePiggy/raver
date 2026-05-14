# Raver 商用级架构改造总结

> Status: Active
> Owner: Architecture / Backend / iOS / Web Admin
> Last Updated: 2026-05-13
> Related:
> - `docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_PLAN.md`
> - `docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md`
> - `docs/RAVER_PLATFORM_ARCHITECTURE.md`
> - `docs/RAVER_CONTENT_CMS_UNIFIED_ADMIN_PLAN.md`

## 1. 总结结论

本轮商用级架构改造的核心目标已经达成：

- 项目从“快速迭代期的横向文件堆叠”收束为“按领域、主线、边界、验证记录组织”的平台级工程结构。
- 后端建立了 `modules/`、`jobs/`、`shared/`、`infrastructure/` 等目标骨架，并逐步把 notification、check-in、share、IM、feed、events、music、admin 等能力纳入模块边界。
- iOS 完成 Repository 层逻辑收束，主要 ViewModel 不再继续直接依赖巨型 service。
- Tencent IM 被明确为当前 IM 主线，OpenIM 被降级为 legacy / migration reference。
- Feed / Events / Music 复杂内容域完成第一轮边界收束，并通过真实运行 smoke。
- Web Admin 从散落页面升级为统一后台工作台。
- `festival-viewer` 已从 Python 单独入口收束到 `/admin` 统一入口下，并改为完整页面跳转，不再 iframe 内嵌。
- 数据库备份门禁、路线防漂移、临时文件清理、iOS DerivedData 缓存保留等工程纪律已经写入 tracker 并在执行中遵守。

因此，若按本轮 tracker 的 Phase 0-7 第一批范围理解，可以认为本次架构改造已经通过。

需要特别说明：这不等于正式 RBAC、入驻组织、艺人认领、内容所有权统一表已经完成。这些属于后续商用化深化阶段，涉及数据库设计和数据迁移，执行前必须重新走数据库备份门禁。

## 2. 初始问题

本次改造开始前，项目的主要问题不是功能不足，而是系统复杂度已经进入平台级，但工程组织仍有快速迭代期痕迹：

- 后端 route / service / script 横向平铺，领域归属不清晰。
- iOS ViewModel、Service、Repository 边界混杂，容易形成 God Service。
- OpenIM、Tencent IM、旧通知、新通知、Check-in v1 / v2 等主线与历史兼容容易混淆。
- Web Admin、CMS、预登记、通知后台、OpenIM 历史后台入口分散。
- 数据库结构、projection、snapshot、outbox、audit 等概念缺少统一门禁和 ownership。
- 复杂内容域如 Feed、Events、Music、Rating、Profile 发布物等已经接近平台级，但代码边界仍偏功能堆叠。

所以本轮目标不是简单“整理目录”，而是用商用级项目方式回答：

- 当前主线是什么？
- 哪些是 legacy？
- 哪些模块负责哪些领域？
- 哪些数据动作必须备份？
- 哪些 API 属于 App、Admin、Public、Internal 或 Legacy？
- 哪些后续需求必须进入 backlog，而不是插入当前主线？

## 3. 执行原则

本轮改造执行过程中采用以下原则：

- 先收束边界，再移动代码。
- 按领域拆分，而不是按页面拆分。
- 旧入口保持兼容，新入口逐步成为主线。
- 不做一次性大爆炸重构。
- 不把 God Service 直接搬成 Fat Repository。
- 不顺手加入推荐算法、商业化、审核扩展等外扩功能。
- 任何 schema migration、backfill、projection rebuild、snapshot rebuild、批量修复前必须先备份数据库并验证可读。
- iOS build 复用 `/tmp/raver-xcodebuild-derived`，避免每轮全量编译。
- 通过后删除一次性临时日志和 smoke 响应文件，不堆积过程产物。

## 4. Phase 结果

### Phase 0：架构冻结与命名对齐

目标：先建立规则和主线文档，不急着大规模改代码。

结果：

- 新增并启用架构改造 tracker。
- 建立 docs 入口、ADR 入口、legacy / current mainline inventory。
- 建立后端 module ownership 文档。
- 建立 iOS Repository 命名和模块指南。
- 建立数据库备份门禁。
- 建立新增需求防漂移规则。

价值：

- 后续每一步都有 checkbox、验证记录和风险记录。
- 新人可以通过 docs index 找到当前主线。
- 不再靠聊天记录判断哪些是当前方案。

### Phase 1：后端模块骨架

目标：建立模块化单体骨架，但不破坏现有 API。

结果：

- 新增 `server/src/modules/`。
- 新增 `server/src/shared/`。
- 新增 `server/src/infrastructure/`。
- 新增 `server/src/jobs/`。
- 以 notification center 作为第一个迁移试点。
- 旧 route 保留兼容，新 module 作为领域入口。

验证：

- `cd server && pnpm build` 通过。

价值：

- 后端从横向 route / service 平铺，开始有领域模块入口。
- 为后续 Check-in、Share、IM、Feed、Events、Music、Admin 收束建立模板。

### Phase 2：Check-in 和 Share 收束

目标：迁移边界清楚、工程价值高的模块，同时验证数据库备份门禁。

结果：

- 执行数据库备份并验证可读。
- 迁移 Check-in module。
- 将 projection worker 放入 `jobs/checkin-projection/`。
- 迁移 Share module。
- 明确 Check-in v2 projection read model ownership。

数据库备份：

```text
backups/raver_20260512_120657_before_phase2.dump
```

验证：

- `pg_restore --list` 通过。
- `cd server && pnpm build` 通过。
- `pnpm checkins:projection:freshness` 通过。
- `pnpm checkins:projection:run` 通过。
- `pnpm share-links:smoke` 通过。

价值：

- 数据库动作前备份不再只是口头规则，而是完成了一次真实门禁流程。
- Check-in projection 和 Share link 不再散落为孤立能力。

### Phase 3：iOS Repository 层收束

目标：让 ViewModel 不继续直接依赖巨型 service。

结果：

- Notifications ViewModel 改为依赖 `NotificationRepository` protocol。
- Share 建立 `ShareLinkRepository`。
- Event、DJ、Set、Feed、Squad 等建立或扩展 repository protocol。
- `SocialService`、`WebFeatureService`、`ShareLinkService` 降级为底层 API client / adapter。
- 标记并治理 Fat Repository 风险。
- 保留现有物理目录布局，不做大规模文件搬迁。

关键取舍：

- 本阶段优先做逻辑边界，不追求一次性物理目录完美。
- 避免把原来的 God Service 平移成新的 Fat Repository。

验证：

- 多轮 iOS 增量 build 通过。
- `git diff --check` 通过。
- `plutil -lint` 通过。
- `/tmp/raver-xcodebuild-derived` 后续保留，不再每轮清理。

价值：

- ViewModel 到数据源的依赖边界清楚很多。
- 后续单模块 mock、preview、测试有了 seam。

### Phase 4：IM 和 Squad 收束

目标：确认 Tencent IM 当前主线，隔离 OpenIM 历史兼容。

结果：

- 后端新增 `server/src/modules/im/`，作为 Tencent IM 当前主线 facade。
- 业务层 direct import Tencent IM provider 的路径被收束。
- OpenIM 后端和 iOS 相关目录标记 legacy / migration。
- iOS `Infrastructure/TencentIM/` 承接 SDK 会话、store、search index、media resolver、probe logger 等能力。
- 旧 `MessagesRepository` 拆为更小边界，例如 `ConversationRepository`、`MessageNotificationRepository`、`ChatMessageRepository`。
- Squad offline activity 与 IM group sync 分清边界。

验证：

- 后端 build 通过。
- 多轮 iOS 增量 build 通过。
- 用户真实运行 smoke 通过：
  - Tencent IM bootstrap 正常。
  - conversation list 正常。
  - direct / group chat open 正常。
  - group member sync 正常。

价值：

- IM 当前主线不再混乱。
- OpenIM 不再被误认为当前产品路线。
- Squad 线下协同和 IM 群组同步职责分离。

### Phase 5：Feed / Events / Music 大领域收束

目标：处理复杂内容域，把内容平台能力从“页面功能堆叠”收束为领域能力。

结果：

- 迁移 `feed` module。
- 将 FeedEvent、Post interactions、Post comment tree 收束。
- 迁移 `events` module。
- 迁移 `music` module。
- iOS Discover 拆分 Events / DJs / Sets / Wiki。
- 进一步完成 Rating、Profile adapter、Events adapter、Music adapter、Feed adapter 等边界治理。
- 后端 content module facade、FeedEvent telemetry service、PostInteraction service、PostComment service 完成 closure。

验证：

- 后端 build 通过。
- iOS build 通过。
- Feed latest / recommended curl smoke 通过。
- Comments curl smoke 通过。
- 用户真实运行 smoke 通过：
  - Feed 发布、刷新、点赞、收藏、评论正常。
  - Event 详情正常。
  - DJ 详情正常。
  - Set 详情正常。

价值：

- 内容系统从 App 页面视角，转为内容领域视角。
- Feed、Events、Music 后续可以继续朝内容平台演进，而不是继续挤在几个 service 里。

### Phase 6：Admin / Operations 商用化

目标：把 Web/Admin 从页面集合升级为运营系统。

结果：

- 新增 `docs/RAVER_ADMIN_OPERATIONS_PHASE6_INVENTORY.md`。
- 建立 `/api/admin/v1` Admin API facade。
- notification、pre-registration、checkin projection status、virtual asset grant 等运营入口统一到 Admin facade。
- 建立 shared admin auth / role policy。
- AdminAuditLog 写入服务接入既有 `admin_audit_logs` 表。
- 新增 audit query endpoint。
- 新增 `/api/admin/v1/status` 聚合 endpoint。
- Web Admin 接入统一 API client。
- `/admin` 成为后台工作台 / 运营总览入口。
- OpenIM admin client/page 降级为 legacy / deferred。

验证：

- 多轮 `cd server && pnpm build` 通过。
- 多轮 `cd web && pnpm build` 通过。
- `git diff --check` 通过。
- 仅有既有 React hook dependency 和 `<img>` lint warning。

价值：

- Admin API namespace 开始统一。
- 运营入口不再散落。
- 敏感操作开始有审计入口。
- Worker / projection / notification 状态有统一查看入口。

当前未完全关闭项：

- 后台敏感操作“完整权限和审计覆盖”仍需后续做硬边界审计。
- 若未来执行运营数据迁移或批量修复，仍必须先备份数据库。

### Phase 7：Content CMS 统一后台入口

目标：把 `festival-viewer` 从 Python 单独入口收束到统一 Web Admin 后台。

结果：

- 新增 `/admin/content-cms`。
- `/admin` 从纯运营总览升级为后台工作台。
- Navigation 只保留一个“后台管理”入口。
- `festival-viewer` 通过 Next rewrites 挂到：

```text
/admin/festival-viewer.html
/admin/festival-viewer/*
```

- 代理 `festival-viewer` 依赖的专用 API：

```text
/api/raver/*
/api/viewer/*
/api/coze/*
/api/scrape/*
/api/dj-source-cache/*
/api/proxy-image
/api/open-folder
/api/search
```

- 新增 Web role policy helper：

```text
web/src/lib/admin/role-policy.ts
```

- `festival-viewer` 最终采用完整页面跳转，不使用 iframe 内嵌。
- `/admin/content-cms` 负责权限检查和登录态同步，然后跳转到完整页面：

```text
/admin/festival-viewer.html
```

- 新增一键启动脚本：

```text
./start-all.sh
```

该脚本同时启动：

- 主后端：`http://127.0.0.1:3901`
- Festival Viewer WebTool：`http://127.0.0.1:8000`
- Web 前端：`http://127.0.0.1:3000`

并注入：

```bash
RAVER_BFF_BASE=http://127.0.0.1:3901
NEXT_PUBLIC_API_URL=http://127.0.0.1:3901/api
FESTIVAL_VIEWER_ORIGIN=http://127.0.0.1:8000
```

验证：

- `cd web && pnpm build` 通过。
- `bash -n start-all.sh` 通过。
- `git diff --check` 通过。
- 用户确认真实运行测试通过。

价值：

- 后台不再有 Python 工具单独入口的产品割裂感。
- 内容 CMS 和运营后台都从 `/admin` 进入。
- 保留 festival-viewer 成熟工具链，避免重写风险。
- 为后续正式 RBAC / Organization / ArtistClaim 做了入口层准备。

## 5. 角色与权限阶段结果

本轮完成的是入口层和现有 owner / contributor 体系下的权限表达：

| 角色 | 当前落地方式 | 当前能力 |
| --- | --- | --- |
| `admin` | `User.role = admin` | 全站内容管理、运营状态、通知中心、预登记后台 |
| `operator` | `User.role = operator` | 运营协作、预登记、状态巡检、内容工具访问 |
| `organizer` | `User.role = organizer` + `Event.organizerId` | 官方发布活动 / 资讯，维护自己名下活动 |
| `artist` | `User.role = artist` + DJ contributor / future claim | 维护艺人资料，同时具备普通用户内容管理 |
| `user` | `User.role = user` + existing owner fields | 管理自己上传的活动、DJ、Set、资讯 |

本轮没有新增正式 RBAC 数据表。

后续正式商用权限模型建议单独设计：

- `Organization`
- `OrganizationMember`
- `ArtistClaim`
- `ContentOwnership`
- `AdminRolePolicy`

这些都会涉及数据库迁移，执行前必须备份。

## 6. 数据库与备份情况

本轮只有 Phase 2 执行了数据库备份：

```text
backups/raver_20260512_120657_before_phase2.dump
```

验证方式：

```bash
pg_restore --list backups/raver_20260512_120657_before_phase2.dump
```

Phase 3-7 没有执行：

- Prisma migration
- schema 变更
- backfill
- 批量 update / delete / insert
- projection rebuild
- snapshot rebuild
- IM sync apply
- 群组关系修复
- 运营数据批量修复

因此 Phase 3-7 不需要新增数据库备份记录。

## 7. 验证汇总

本轮主要验证方式包括：

- `cd server && pnpm build`
- `cd web && pnpm build`
- iOS `xcodebuild ... -derivedDataPath /tmp/raver-xcodebuild-derived build`
- `plutil -lint`
- `git diff --check`
- `pnpm checkins:projection:freshness`
- `pnpm checkins:projection:run`
- `pnpm share-links:smoke`
- Feed / comments curl smoke
- 用户真实运行 smoke
- `bash -n start-all.sh`

已知 Web build warning：

- 既有 React hook dependency warning。
- 既有 `<img>` optimization warning。

这些 warning 不是本轮新增阻塞。

## 8. 本轮改造后的项目状态

当前项目可以粗略理解为：

```text
Raver = iOS App 主客户端
      + Express/Prisma 模块化单体后端
      + Tencent IM 当前实时通讯主线
      + Notification Center / APNs 当前通知主线
      + Check-in v2 projection 当前打卡主线
      + Feed / Events / Music 内容平台能力
      + Web Admin / Content CMS 统一后台入口
      + legacy / migration 清晰隔离
```

最重要的变化是：

- 项目不再只是“能跑的功能集合”，而是有了工程主线。
- 每个阶段有验证、有边界、有风险记录。
- 后续继续改造时，不需要从混乱状态重新判断方向。

## 9. 剩余事项

本轮通过后，仍建议把以下事项作为下一阶段处理。

### 9.1 Phase 6 权限与审计硬边界审计

需要检查所有后台和内容写接口是否真正符合：

- admin 可以管理全部内容。
- operator 只能做运营协作范围内操作。
- organizer 只能管理自己主办方名下活动 / 资讯。
- artist 只能维护自己认领 / 贡献的艺人资料。
- user 只能管理自己上传 / 贡献的内容。

这一阶段优先做审计和文档，不急着改数据库。

### 9.2 正式 RBAC / 入驻主体模型

当入口和现有权限边界稳定后，再设计：

- Organization
- OrganizationMember
- ArtistClaim
- ContentOwnership
- AdminRolePolicy

这属于数据库改造阶段，必须先备份。

### 9.3 `festival-viewer` 长期归属

当前方案保留 festival-viewer 成熟工具链，并通过 Web Admin 统一入口访问。

后续可以分三步：

1. 短期：继续保留 Python WebTool，保证运营效率。
2. 中期：把核心写接口逐步迁入 Nest/Express Admin API。
3. 长期：把高频内容管理能力拆成原生 Web Admin 页面。

### 9.4 Tracker Closure 清理

如果你确认所有真实运行测试都通过，可以在 tracker 中进一步处理：

- 将 Phase 7 状态从 `[~]` 调整为 `[x]`。
- 将 Phase 6 中已满足的审计项细化或拆到下一阶段。
- 更新“当前执行路径”和“下一步建议”，避免它继续停留在旧任务描述上。

## 10. 结论

本次改造已经完成了从“复杂项目”到“可持续维护的平台级项目”的关键转折：

- 主线清楚了。
- legacy 隔离了。
- 后端模块化骨架起来了。
- iOS repository 边界收住了。
- IM 主线明确了。
- 内容域完成第一轮收束。
- Admin / Operations 有统一入口和 API facade。
- Content CMS 接入统一后台。
- 数据库安全门禁落地了。

后续不应该再回到“哪里乱改哪里”的方式，而应该继续沿用本轮形成的节奏：

```text
先写 scope -> 再定边界 -> 小批次实现 -> build/smoke -> 记录 tracker -> 再进入下一批
```

这就是本轮改造最重要的工程资产。
