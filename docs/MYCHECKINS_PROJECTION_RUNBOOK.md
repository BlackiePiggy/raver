# MyCheckins Projection Monitoring And Recovery Runbook

本文档用于 MyCheckins v2 投影读模型的日常巡检、告警处理、回填修复和紧急止损。

适用范围：

- iOS MyCheckins / 我的打卡页面
- `/v2/*/checkins/overview`
- `/v2/*/checkins/timeline`
- `/v2/*/checkins/gallery/events`
- `/v2/*/checkins/gallery/djs`
- `/v2/*/checkins/stats`
- checkin snapshot / timeline / stats / gallery projection tables

不适用范围：

- 年度回顾
- 分享海报完整生成链路
- 推荐系统
- 用户画像标签
- 排行榜、勋章、成就
- Android

---

## 1. 当前商用策略

MyCheckins v2 查询接口已经进入 strict read model 模式。

这意味着：

- iOS 页面查询只读 projection tables，不再 fallback 到写模型直读。
- projection 正常时，页面首屏可以稳定读取轻量 DTO。
- projection 缺失或不新鲜时，接口返回 `503` 与 `CHECKIN_PROJECTION_NOT_READY`。
- 运维修复的首选动作是跑 worker / reproject / snapshot rebuild，而不是重新打开旧 fallback。

核心原则：

1. 页面性能靠读模型保证。
2. 数据正确性靠可重建 projection 保证。
3. 故障暴露靠 health status / freshness script 保证。
4. 紧急止损优先修 projection，不轻易回退业务读链路。

---

## 2. 健康状态口径

共享状态服务：

- `server/src/services/checkin-projection-status.ts`

命令行监控：

```bash
cd /Users/blackie/Projects/raver/server
pnpm checkins:projection:freshness
```

后台状态接口：

```http
GET /v2/admin/checkins/projection/status
Authorization: Bearer <admin-or-operator-token>
```

状态字段：

| 字段 | 含义 |
| --- | --- |
| `status` | `healthy` / `degraded` / `critical` |
| `projectionVersion` | 当前代码要求的 projection 版本 |
| `dirtyCheckins` | 仍低于当前 projectionVersion 的 active checkin 数 |
| `pendingOutbox` | 等待处理的 outbox 事件数 |
| `pendingReadyOutbox` | 已到 `availableAt`、可以立即处理的 pending 事件数 |
| `deadOutbox` | 已进入 dead 状态、需要人工介入的事件数 |
| `projectedUsers` | 已有 user checkin stat projection 的用户数 |
| `oldestPendingAgeSeconds` | 最老 pending 事件从创建到当前的秒数 |
| `alertReasons` | 告警原因列表 |
| `checkedAt` | 本次检查时间 |

状态判断：

| 状态 | 条件 | 处理级别 |
| --- | --- | --- |
| `healthy` | `dirtyCheckins=0`、`pendingOutbox=0`、`deadOutbox=0` | 正常 |
| `degraded` | 存在 dirty checkins 或 pending outbox，但未超过 critical 阈值 | 尽快修复 |
| `critical` | `deadOutbox>0` 或最老 pending 超过 15 分钟 | 事故处理 |

脚本退出码：

| 退出码 | 含义 |
| --- | --- |
| `0` | healthy |
| `1` | degraded |
| `2` | critical |

---

## 3. 日常巡检

建议巡检频率：

- 测试环境：每次后端发布后执行一次。
- 生产环境：每 1-5 分钟由定时任务或监控系统执行一次。
- 用户反馈 MyCheckins 空白、503、数据不对时立即执行。

标准命令：

```bash
cd /Users/blackie/Projects/raver/server
pnpm checkins:projection:freshness
```

健康样例：

```json
{
  "projectionVersion": 1,
  "status": "healthy",
  "dirtyCheckins": 0,
  "pendingOutbox": 0,
  "pendingReadyOutbox": 0,
  "deadOutbox": 0,
  "projectedUsers": 6,
  "oldestPendingAvailableAt": null,
  "oldestPendingCreatedAt": null,
  "oldestPendingAgeSeconds": 0,
  "alertReasons": []
}
```

验收标准：

- `status=healthy`
- `dirtyCheckins=0`
- `pendingOutbox=0`
- `deadOutbox=0`
- iOS MyCheckins 首屏、timeline 加载更多、活动画廊、DJ 画廊、stats 正常

---

## 4. 告警建议

最低可商用告警：

| 指标 | 阈值 | 级别 | 处理 |
| --- | --- | --- | --- |
| `deadOutbox` | `>0` | P1 | 立即人工介入 |
| `oldestPendingAgeSeconds` | `>=900` | P1 | worker 或 DB / 服务异常排查 |
| `dirtyCheckins` | `>0` 持续 5 分钟 | P2 | 执行 dirty reproject |
| `pendingOutbox` | `>0` 持续 5 分钟 | P2 | 执行 projection worker |
| v2 查询 `CHECKIN_PROJECTION_NOT_READY` | 5 分钟内持续出现 | P1/P2 | 查对应用户 projection |
| v2 查询 5xx | 超过业务基线 | P1/P2 | 查服务端错误日志 |

建议 dashboard：

- MyCheckins v2 请求量、P50/P95/P99 耗时
- MyCheckins v2 4xx/5xx 数量
- `CHECKIN_PROJECTION_NOT_READY` 次数
- dirty checkins
- pending / ready / dead outbox
- oldest pending age
- projection worker 执行结果

---

## 5. degraded 处理流程

### 5.1 pendingOutbox 大于 0

先跑 worker：

```bash
cd /Users/blackie/Projects/raver/server
pnpm checkins:projection:run
```

然后复查：

```bash
pnpm checkins:projection:freshness
```

如果仍有 pending：

1. 看 `pendingReadyOutbox` 是否大于 0。
2. 如果 ready 大于 0 但 worker 处理失败，查看 worker 输出和服务端日志。
3. 如果 pending 还没到 `availableAt`，等待下一轮或确认 retry 策略是否正常。

### 5.2 dirtyCheckins 大于 0

先 dry-run：

```bash
cd /Users/blackie/Projects/raver/server
pnpm checkins:reproject:dirty -- --limit 50
```

确认输出用户数与 projection report 合理后 apply：

```bash
pnpm checkins:reproject:dirty -- --limit 50 --apply
```

然后复查：

```bash
pnpm checkins:projection:freshness
```

如果 dirty 仍大于 0，继续按 batch 处理，直到清零。

---

## 6. critical 处理流程

### 6.1 deadOutbox 大于 0

处理原则：

- 不要直接删除 dead outbox。
- 先定位失败用户和失败原因。
- 修复数据或代码后再 reproject 对应用户。

操作顺序：

1. 查询 dead outbox 明细。
2. 定位 `userId`、`aggregateId`、`eventType`。
3. 检查对应 checkin / snapshot / selections 是否存在异常。
4. 对单用户执行 dry-run reproject。
5. 确认无异常后 apply。
6. 如 dead outbox 是已修复的历史失败事件，再由后续专门管理脚本或人工 SQL 标记归档。

单用户 reproject：

```bash
cd /Users/blackie/Projects/raver/server
pnpm checkins:reproject:user -- --user-id <userId>
pnpm checkins:reproject:user -- --user-id <userId> --apply
pnpm checkins:projection:freshness
```

### 6.2 pending 老化超过 15 分钟

优先判断 worker 是否没有运行：

```bash
cd /Users/blackie/Projects/raver/server
pnpm checkins:projection:run
pnpm checkins:projection:freshness
```

如果 worker 运行后仍持续老化：

- 查数据库连接。
- 查 Prisma / Node 服务日志。
- 查是否有特定用户 projection rebuild 一直失败。
- 对失败用户单独 dry-run reproject。

---

## 7. snapshot 修复

snapshot 只负责展示快照，不是最终事实源。

当出现以下情况时使用 snapshot rebuild：

- 用户打卡卡片展示名称、封面、地址不正确。
- selections 事实数据正确，但 snapshot 摘要过旧。
- 后台修正 event / DJ 基础信息后，需要允许快照重建修正。

dry-run：

```bash
cd /Users/blackie/Projects/raver/server
pnpm checkins:snapshots:rebuild -- --user-id <userId> --limit 100
```

apply：

```bash
pnpm checkins:snapshots:rebuild -- --user-id <userId> --limit 100 --apply
```

全局分批：

```bash
pnpm checkins:snapshots:rebuild -- --limit 100
pnpm checkins:snapshots:rebuild -- --limit 100 --apply
```

snapshot rebuild 后，如 timeline / gallery / stats 仍不正确，再执行对应用户 reproject。

---

## 8. 接口故障处理

### 8.1 iOS 收到 CHECKIN_PROJECTION_NOT_READY

含义：

- 用户存在。
- 但该用户 read model 不存在或低于当前 projection version。
- strict mode 正在正确暴露数据未准备好问题。

处理：

```bash
cd /Users/blackie/Projects/raver/server
pnpm checkins:reproject:user -- --user-id <userId>
pnpm checkins:reproject:user -- --user-id <userId> --apply
pnpm checkins:projection:freshness
```

验收：

- 对应用户 `/v2/*/checkins/overview` 不再返回 `CHECKIN_PROJECTION_NOT_READY`。
- iOS MyCheckins 首屏正常。

### 8.2 iOS 收到 404 User not found

含义：

- 用户不存在或 userId 错误。
- 这不是 projection 故障。

处理：

- 查登录态和目标 userId。
- 不跑 reproject。

### 8.3 iOS 首屏慢

先确认服务端 projection 健康：

```bash
cd /Users/blackie/Projects/raver/server
pnpm checkins:projection:freshness
```

如果 healthy 但首屏仍慢：

- 查 `/v2/*/checkins/overview` P95/P99。
- 查 iOS 图片加载、网络、主线程阻塞。
- 不应回到 `/v1/checkins` 多接口聚合链路。

---

## 9. 回滚策略

当前推荐策略：

1. 优先修 projection。
2. 优先单用户修复，避免全量重建影响面过大。
3. 批量 dirty 用户按 limit 分批 apply。
4. 不建议重新开启写模型直读 fallback。

为什么不建议恢复 fallback：

- fallback 会重新引入慢查询与客户端等待风险。
- fallback 会让线上问题被掩盖，projection 长期不新鲜。
- fallback 会让 `/v2` 商用合同从“稳定读模型”退回“双链路不确定状态”。

可接受的紧急止损：

- 回滚到上一个已验证的服务端提交。
- 保留 strict mode，但通过 reproject / snapshot rebuild 修复数据。
- 若必须临时恢复 fallback，必须作为事故临时分支处理，并在事故结束后删除，不进入长期主线。

不可接受的止损：

- 直接删除 outbox。
- 直接修改 projection 表但不修事实数据。
- 让 iOS 重新依赖 `/v1/checkins` 主链路。
- 在 MyCheckins 页面重新加入 event / DJ 补查和客户端聚合规则。

---

## 10. 发布验收清单

- [ ] `pnpm build` 通过。
- [ ] `pnpm checkins:projection:freshness` 返回 `status=healthy`。
- [ ] `dirtyCheckins=0`。
- [ ] `pendingOutbox=0`。
- [ ] `deadOutbox=0`。
- [ ] admin/operator 可访问 `/v2/admin/checkins/projection/status`。
- [ ] 普通用户不可访问 `/v2/admin/checkins/projection/status`。
- [ ] iOS MyCheckins 首屏正常。
- [ ] iOS timeline 手动加载更多正常。
- [ ] iOS 活动画廊分页正常。
- [ ] iOS DJ 画廊分页正常。
- [ ] private / visible 可见性正常。

---

## 11. 当前已验证记录

2026-05-06 本地开发库：

- `pnpm checkins:reproject:dirty -- --limit 50 --apply` 已执行。
- `dirtyCheckins=0`。
- `pendingOutbox=0`。
- `deadOutbox=0`。
- `projectedUsers=6`。
- 用户确认 iOS 端到端正常。

---

## 12. 后续可以增强但不进入当前主线

- 把 health status 接入 Prometheus / Grafana。
- 给 admin 后台加 MyCheckins Projection 状态面板。
- 给 dead outbox 增加专门 retry / archive 管理脚本。
- 给 projection worker 增加常驻后台进程或队列系统。
- 给 `CHECKIN_PROJECTION_NOT_READY` 增加按用户聚合的告警。
