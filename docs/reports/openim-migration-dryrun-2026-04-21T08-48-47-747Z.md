# OpenIM 历史消息迁移 Dry-Run 报告

- 运行时间：2026-04-21T08:48:47.748Z ~ 2026-04-21T08:48:47.829Z
- 耗时：81 ms
- 模式：all
- 扫描消息总数：25
- 候选迁移消息总数：25
- 是否写入 openim_message_migrations：是

## 1. 扫描配置

- conversation batch size: 100
- message batch size: 500
- issue sample limit: 30

## 2. 数据摘要

| sourceType | conversations | messages | candidates | unsupportedType | senderContextIssues | outOfOrder | futureTimestamp | earliest | latest |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| direct_message | 12 | 16 | 16 | 0 | 0 | 0 | 0 | 2026-03-18T03:44:37.242Z | 2026-04-11T06:30:26.297Z |
| squad_message | 5 | 9 | 9 | 0 | 0 | 0 | 0 | 2026-03-18T03:23:24.808Z | 2026-03-27T08:38:18.700Z |

## 3. 历史迁移状态表统计

| sourceType | status | count |
| --- | --- | ---: |
| direct_message | pending | 16 |
| squad_message | pending | 9 |

## 4. 异常样本（截断）

_未发现异常样本_

## 5. sendTime 策略结论

- 建议迁移时直接使用旧消息 `createdAt` 毫秒时间戳作为 `sendTime`。
- 若发现未来时间戳消息，请在正式迁移前先清理异常数据，避免 OpenIM 历史顺序异常。
- 正式迁移阶段按会话 `createdAt asc, id asc` 串行发送，保证稳定顺序。

## 6. 下一步建议

1. 先以 `OPENIM_MIGRATION_DRYRUN_PERSIST=true` 再跑一轮，固化 `openim_message_migrations` 待迁移基线。
2. 新增真实迁移执行器：读取 `openim_message_migrations(status=pending)`，调用 OpenIM send message，成功后回写 targetMessageId/migratedAt。
3. 跑首轮沙箱迁移后，按会话抽样校验消息顺序与时间。
