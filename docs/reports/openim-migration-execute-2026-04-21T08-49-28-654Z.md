# OpenIM 历史消息迁移执行报告

- 运行时间：2026-04-21T08:49:28.655Z ~ 2026-04-21T08:49:28.731Z
- 执行发送：是
- OpenIM enabled：true
- sourceType：direct_message
- batchSize：1
- maxMessages：1
- failFast：false

## 1. 执行摘要

| scannedRows | directRows | squadRows | planned | migrated | failed | skipped |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1 | 0 | 0 | 1 | 0 | 0 |

## 2. 样本

| sourceType | sourceId | conversationKey | status | targetMessageId | error |
| --- | --- | --- | --- | --- | --- |
| direct_message | 2b320d36-9077-4526-ab84-a5f11a2e29ed | single:u_0fcba61a6bf340108e33981ed7a2b0e0:u_6bfc321407094cbab77e1f21781bee33 | migrated | f5506c76e204667060e9a198e2103719 | - |

## 3. 下一步

- 检查 failed/skipped 行，修复后重新执行同一脚本。
