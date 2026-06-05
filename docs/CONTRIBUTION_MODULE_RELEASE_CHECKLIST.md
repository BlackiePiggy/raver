# 贡献模块发布与回填 Checklist

关联文档：

- [CONTRIBUTION_MODULE_EXECUTION_TRACKER.md](/Users/blackie/Projects/raver/docs/CONTRIBUTION_MODULE_EXECUTION_TRACKER.md)
- [EVENT_DJ_CONTRIBUTOR_LIST_PLAN.md](/Users/blackie/Projects/raver/docs/EVENT_DJ_CONTRIBUTOR_LIST_PLAN.md)

---

## 1. 使用目标

这份清单只服务于 `贡献模块` 发布与回填 cutover，覆盖：

- 本地开发完成后的最低门禁
- 准线上 / 线上环境正式回填前检查
- 正式回填执行步骤
- 回填后抽样校验
- iOS / web / backend smoke
- 异常时的回滚处理顺序

这份清单默认把 `正式回填` 视为发布窗口动作，而不是本地开发阻塞项。

---

## 2. 本地完成门禁

以下项目在本地完成即可，不要求先执行正式回填：

- [ ] `server` 编译通过。
- [ ] 贡献模块回填脚本可编译。
- [ ] 贡献模块 verify 脚本可编译。
- [ ] `event` 全量 `dry-run` 能跑通并输出 summary。
- [ ] `dj` 全量 `dry-run` 能跑通并输出 summary。
- [ ] 服务端贡献写入日志已接入。
- [ ] 贡献模块回归脚本可跑通。
- [ ] tracker 已同步当前真实进度。

建议命令：

```bash
cd /Users/blackie/Projects/raver/server
pnpm build
CONTRIBUTION_MODULE_BACKFILL_ENTITY_TYPES=event pnpm contribution-module:backfill
CONTRIBUTION_MODULE_BACKFILL_ENTITY_TYPES=dj pnpm contribution-module:backfill
pnpm contribution-module:verify
pnpm contribution-module:regression
```

说明：

- 本地 `dry-run` 主要验证脚本逻辑、分页读取、日志输出、连接重试。
- 本地环境不要求先完成正式回填。

---

## 3. 准线上 / 线上正式回填前检查

正式回填前必须确认：

- [ ] 目标环境 migration 已全部部署完成。
- [ ] 目标环境 Prisma client 与当前 schema 对齐。
- [ ] 回填窗口内没有并发执行其他同表大规模 backfill / repair。
- [ ] 已确认当前应用版本包含贡献模块读写链路。
- [ ] 已确认 `no-op` 判定逻辑已上线。
- [ ] 已准备好回填后 verify 抽样校验命令。
- [ ] 已准备好回滚顺序说明。

建议命令：

```bash
cd /Users/blackie/Projects/raver/server
pnpm prisma:generate
pnpm prisma migrate status
pnpm build
```

---

## 4. 正式回填执行顺序

建议严格按顺序执行，不建议 `event` 与 `dj` 在同一窗口并发跑。

### 4.1 先跑 event

- [ ] 先执行 `event` 正式回填。
- [ ] 观察分页日志、fallback 统计、是否有重试。
- [ ] 回填结束后记录 summary。

建议命令：

```bash
cd /Users/blackie/Projects/raver/server
CONTRIBUTION_MODULE_BACKFILL_APPLY=1 \
CONTRIBUTION_MODULE_BACKFILL_ENTITY_TYPES=event \
pnpm contribution-module:backfill
```

### 4.2 再跑 dj

- [ ] 再执行 `dj` 正式回填。
- [ ] 观察 `dj_legacy_page_loaded` 分页日志。
- [ ] 回填结束后记录 summary。

建议命令：

```bash
cd /Users/blackie/Projects/raver/server
CONTRIBUTION_MODULE_BACKFILL_APPLY=1 \
CONTRIBUTION_MODULE_BACKFILL_ENTITY_TYPES=dj \
pnpm contribution-module:backfill
```

建议：

- 如果线上连接稳定但单页 payload / legacy 扫描偏慢，可保守设置：

```bash
CONTRIBUTION_MODULE_BACKFILL_READ_BATCH_SIZE=10
CONTRIBUTION_MODULE_BACKFILL_DJ_LEGACY_READ_BATCH_SIZE=500
```

- 如果需要缩小风险面，可以先用单对象 smoke：

```bash
CONTRIBUTION_MODULE_BACKFILL_EVENT_ID=<eventId> pnpm contribution-module:backfill
CONTRIBUTION_MODULE_BACKFILL_DJ_ID=<djId> pnpm contribution-module:backfill
```

---

## 5. 回填后 verify 抽样校验

正式回填后必须执行 verify。

### 5.1 全量 verify

- [ ] 跑全量 verify summary。
- [ ] 记录 `warningCount` / `errorCount`。

```bash
cd /Users/blackie/Projects/raver/server
pnpm contribution-module:verify
```

### 5.2 event 抽样

- [ ] 抽样 20 个 event。
- [ ] 确认 registry 存在。
- [ ] 确认 creator 行存在。
- [ ] 确认列表排序与贡献时间范围合理。

```bash
CONTRIBUTION_MODULE_VERIFY_ENTITY_TYPES=event \
CONTRIBUTION_MODULE_VERIFY_SAMPLE_SIZE=20 \
pnpm contribution-module:verify
```

### 5.3 dj 抽样

- [ ] 抽样 20 个 DJ。
- [ ] 确认 registry 存在。
- [ ] 确认 creator 行存在。
- [ ] 确认 contribution count 不小于 history count。

```bash
CONTRIBUTION_MODULE_VERIFY_ENTITY_TYPES=dj \
CONTRIBUTION_MODULE_VERIFY_SAMPLE_SIZE=20 \
pnpm contribution-module:verify
```

---

## 6. Backend Smoke

- [ ] 创建 event 后，creator 进入 `event_contributors`。
- [ ] event 审核编辑成功后，editor 进入贡献列表。
- [ ] 创建 DJ 后，creator 进入 `dj_contributors`。
- [ ] DJ 审核编辑成功后，editor 进入贡献列表。
- [ ] 被拒绝 submission 不写 history。
- [ ] no-op submission 不写 history。
- [ ] contribution center summary 返回正确统计。
- [ ] contribution history 分页与筛选正常。
- [ ] `contribution-module:regression` 脚本跑通。

建议关注日志：

- [ ] `[contribution-module] record_write_started`
- [ ] `[contribution-module] record_write_succeeded`
- [ ] `[contribution-module] record_write_failed`
- [ ] `[backfill-contribution-module] ...`
- [ ] `[verify-contribution-module-backfill] ...`
- [ ] `[contribution-module-regression] ok`

---

## 7. iOS Smoke

### 7.1 对象详情

- [ ] event 详情页显示贡献者摘要。
- [ ] DJ 详情页显示贡献者摘要。
- [ ] 1 人头像 / 名称样式正确。
- [ ] 2 人头像叠放样式正确。
- [ ] 3+ 人头像叠放样式正确。
- [ ] 点击摘要进入完整贡献者列表页。
- [ ] 列表按最近修改倒序。
- [ ] 时间展示为 UTC。
- [ ] 点击 contributor 进入对应用户主页。

### 7.2 贡献中心

- [ ] 个人主页存在 `贡献中心` 快捷入口。
- [ ] 点击后能进入 `ContributionCenterView`。
- [ ] 顶部 summary card 正确。
- [ ] `全部 / Event / DJ` 筛选可用。
- [ ] 历史条目点击跳对应对象详情。
- [ ] 空状态、离线态、失败重试正常。
- [ ] `contribution_center_entry_tapped / exposure / filter_tapped` 埋点触发正常。

---

## 8. Web Smoke

- [ ] event overlay detail 存在独立 `贡献` tab。
- [ ] DJ overlay detail 存在独立 `贡献` tab。
- [ ] `贡献` tab 列表按最近修改倒序。
- [ ] UTC 时间展示正确。
- [ ] contributor 点击跳转正确。
- [ ] `contribution_tab_exposure` 与 `contributor_list_profile_tapped` 埋点触发正常。
- [ ] profile 页贡献历史入口与展示正常。

---

## 9. 异常处理与回滚顺序

如果正式回填执行后发现问题，建议按以下顺序处理：

1. 先停止继续执行 backfill / verify / 相关批处理。
2. 先判断问题属于：
   - 读路径展示问题
   - 回填结果问题
   - schema / migration 问题
3. 如果只是读路径问题：
   - 先回退应用代码
   - 不急于删除回填数据
4. 如果是回填结果问题：
   - 删除 `contribution_history_entries` 中 `source = backfill` 或 `metadata.backfillModule = contribution_module_phase8` 的数据
   - 按目标状态重建 `event_contributors` / `dj_contributors`
5. 如果需要 schema 回滚：
   - 必须先确认线上代码不再依赖新表 / 新字段
   - 再执行 migration 回滚或人工 DDL

---

## 10. 发布结论记录

建议每次正式执行后补一条记录：

- 执行日期：
- 执行环境：
- 执行人：
- event backfill summary：
- dj backfill summary：
- verify summary：
- 是否触发回滚：
- 遗留问题：
