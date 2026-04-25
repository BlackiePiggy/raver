# OpenIM 历史消息迁移执行报告

- 运行时间：2026-04-21T08:54:16.612Z ~ 2026-04-21T08:54:16.708Z
- 执行发送：是
- OpenIM enabled：true
- sourceType：squad_message
- batchSize：20
- maxMessages：20
- failFast：false
- includeFailed：true

## 1. 执行摘要

| scannedRows | directRows | squadRows | planned | migrated | failed | skipped |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 9 | 0 | 9 | 0 | 5 | 0 | 4 |

## 2. 样本

| sourceType | sourceId | conversationKey | status | targetMessageId | error |
| --- | --- | --- | --- | --- | --- |
| squad_message | f77bef61-f810-4ae0-910c-55097442f7a6 | group:g_5dc1e254f0d5452ba32d209890d07378 | skipped | - | legacy squad has 2 member(s), below OpenIM group minimum |
| squad_message | 9d69316f-1e54-4fba-bedb-41ab83de2b62 | group:g_6379f4a61b5944b298f1dc961a8119e9 | skipped | - | legacy squad has 2 member(s), below OpenIM group minimum |
| squad_message | 59440392-fb46-45b8-b2d0-e3005df2e02d | group:g_b63ea9df6dee445eac4979be92572080 | skipped | - | legacy squad has 1 member(s), below OpenIM group minimum |
| squad_message | 442aa3ec-d513-4702-859f-a66f731ff301 | group:g_b63ea9df6dee445eac4979be92572080 | skipped | - | legacy squad has 1 member(s), below OpenIM group minimum |
| squad_message | 727c93a4-e326-4188-a4f6-eb106e05eb59 | group:g_bb04874d61724a20b79b9aeb952c4cce | migrated | a0b283b1dbbe2115101cfcd4e9739629 | - |
| squad_message | a9c47041-dc0f-449d-abd9-0ff6281c7b39 | group:g_bb04874d61724a20b79b9aeb952c4cce | migrated | 141e3c0d2af685e049778bb2ba560c3a | - |
| squad_message | 215c429a-5c08-43aa-a8bd-e8194c6fed3d | group:g_bb04874d61724a20b79b9aeb952c4cce | migrated | d7c8b90791c5bdea14c5e740ba66904b | - |
| squad_message | d8ff28a2-4655-4fa0-80dd-f6f032798b91 | group:g_da057f973c0a492d8973a02c961b1ca1 | migrated | d36d1c96a09c8b381e945a2e37ece3ac | - |
| squad_message | d48fc772-7ee4-4d6d-bf11-316a6c221de1 | group:g_da057f973c0a492d8973a02c961b1ca1 | migrated | b43ee58fc06f5f87bab4ca26d69da369 | - |

## 3. 下一步

- 检查 failed/skipped 行，修复后重新执行同一脚本。
