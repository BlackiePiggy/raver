# OpenIM 历史消息迁移执行报告

- 运行时间：2026-04-21T08:49:15.511Z ~ 2026-04-21T08:49:15.578Z
- 执行发送：是
- OpenIM enabled：true
- sourceType：all
- batchSize：1
- maxMessages：1
- failFast：false

## 1. 执行摘要

| scannedRows | directRows | squadRows | planned | migrated | failed | skipped |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 0 | 1 | 0 | 0 | 1 | 0 |

## 2. 样本

| sourceType | sourceId | conversationKey | status | targetMessageId | error |
| --- | --- | --- | --- | --- | --- |
| squad_message | f77bef61-f810-4ae0-910c-55097442f7a6 | group:g_5dc1e254f0d5452ba32d209890d07378 | failed | - | RecordNotFoundError |

## 3. 下一步

- 检查 failed/skipped 行，修复后重新执行同一脚本。
