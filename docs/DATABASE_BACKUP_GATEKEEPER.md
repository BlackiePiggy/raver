# Database Backup Gatekeeper

> Status: Active  
> Owner: Backend / Data  
> Last Updated: 2026-05-12  
> Applies To: `server/prisma/`、数据库迁移、数据回填、reproject、snapshot rebuild、批量数据修复  
> Purpose: 在任何数据库改造前建立强制备份和验证门禁，避免数据不可恢复。

## 1. 强制规则

以下任何动作执行前，必须先备份当前数据库并验证备份可读：

- Prisma migration
- 手写 SQL schema 变更
- 批量 `update` / `delete` / `insert`
- 数据清洗
- backfill
- reproject apply
- snapshot rebuild
- 删除 legacy 表或字段
- 大规模导入覆盖
- 修改 source of truth 表中的历史数据

没有备份记录，不执行数据库动作。

## 2. 备份记录位置

备份必须记录在：

```text
docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md
```

记录区：

```text
## 4. 数据库备份记录
```

每条记录必须包含：

- 时间
- 环境
- 操作范围
- 备份文件
- 验证方式
- 回滚方式
- 状态

## 3. 环境确认

执行前必须确认当前环境：

| 环境 | 说明 | 要求 |
| --- | --- | --- |
| local | 本地开发库 | 推荐备份 |
| dev | 共享开发环境 | 必须备份 |
| staging | 预发环境 | 必须备份并验证 restore |
| production | 生产环境 | 必须备份、验证、审批、记录回滚方案 |

不得在不明确环境的情况下执行数据动作。

## 4. 标准备份命令

在项目根目录执行：

```bash
mkdir -p backups
pg_dump "$DATABASE_URL" --format=custom --file "backups/raver_$(date +%Y%m%d_%H%M%S).dump"
```

备份后检查文件：

```bash
ls -lh backups/*.dump
```

## 5. 备份可读性验证

最低验证：

```bash
pg_restore --list "backups/<dump-file>.dump" >/tmp/raver_restore_list.txt
wc -l /tmp/raver_restore_list.txt
```

推荐验证：

```bash
createdb raver_restore_smoke
pg_restore --dbname raver_restore_smoke "backups/<dump-file>.dump"
psql raver_restore_smoke -c '\dt'
dropdb raver_restore_smoke
```

如果 restore smoke test 失败，不允许继续执行数据库改造。

## 6. 回滚原则

### 6.1 schema migration 回滚

必须明确：

- migration 文件路径
- 是否可逆
- 回滚 SQL 或恢复 dump 的方式
- 是否影响应用代码

### 6.2 backfill / reproject 回滚

必须明确：

- 影响用户范围
- 影响表
- 是否可重新生成
- 是否可以通过重新 restore 或再次 reproject 修复

### 6.3 production 回滚

生产环境优先策略：

1. 停止相关 worker。
2. 停止继续写入受影响链路。
3. 评估是否用业务修复脚本还是 restore。
4. 记录事故和恢复步骤。

## 7. 数据动作审批清单

执行前填写：

```md
### Database Change Preflight

- [ ] 已确认数据库环境：
- [ ] 已确认本次操作范围：
- [ ] 已确认影响表：
- [ ] 已确认是否涉及 source of truth：
- [ ] 已执行备份：
- [ ] 已验证备份可读：
- [ ] 已记录备份到 tracker：
- [ ] 已准备回滚方式：
- [ ] 已准备验证命令：
```

## 8. 常见场景

### 8.1 Prisma Migration

```bash
mkdir -p backups
pg_dump "$DATABASE_URL" --format=custom --file "backups/raver_$(date +%Y%m%d_%H%M%S)_before_migration.dump"
pg_restore --list "backups/<dump-file>.dump" >/tmp/raver_restore_list.txt
cd server
npx prisma migrate dev
```

### 8.2 Check-in Reproject Apply

```bash
mkdir -p backups
pg_dump "$DATABASE_URL" --format=custom --file "backups/raver_$(date +%Y%m%d_%H%M%S)_before_checkin_reproject.dump"
pg_restore --list "backups/<dump-file>.dump" >/tmp/raver_restore_list.txt
cd server
pnpm checkins:reproject:dirty -- --limit 50 --apply
pnpm checkins:projection:freshness
```

### 8.3 Snapshot Rebuild

```bash
mkdir -p backups
pg_dump "$DATABASE_URL" --format=custom --file "backups/raver_$(date +%Y%m%d_%H%M%S)_before_snapshot_rebuild.dump"
pg_restore --list "backups/<dump-file>.dump" >/tmp/raver_restore_list.txt
cd server
pnpm checkins:snapshots:rebuild
pnpm checkins:projection:freshness
```

## 9. 禁止事项

- 禁止无备份执行数据库改造。
- 禁止只备份不验证。
- 禁止不记录 tracker。
- 禁止在不清楚环境时执行数据动作。
- 禁止把生产数据修复写成一次性不可追踪命令。
- 禁止在架构改造中顺手清理数据，除非有明确计划、备份和回滚。

## 10. Phase 0 状态

- [x] 备份门禁规则已建立。
- [ ] 首次真实数据库改造前，需要执行并记录第一条备份记录。
