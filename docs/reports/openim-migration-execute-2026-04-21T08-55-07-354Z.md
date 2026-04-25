# OpenIM 历史消息迁移执行报告

- 运行时间：2026-04-21T08:55:07.354Z ~ 2026-04-21T08:55:07.491Z
- 执行发送：是
- OpenIM enabled：true
- sourceType：direct_message
- batchSize：20
- maxMessages：20
- failFast：false
- includeFailed：false

## 1. 执行摘要

| scannedRows | directRows | squadRows | planned | migrated | failed | skipped |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 15 | 15 | 0 | 0 | 7 | 8 | 0 |

## 2. 样本

| sourceType | sourceId | conversationKey | status | targetMessageId | error |
| --- | --- | --- | --- | --- | --- |
| direct_message | d8ad04ed-5406-4135-9097-38a48d52ef50 | single:u_1f4cafda6d464dcf8e987d4892d09425:u_322a63f985ba43df8594552ad532968c | failed | - | RecordNotFoundError |
| direct_message | 0000f9af-95bd-4494-8691-1c1e3d94f9fe | single:u_1f4cafda6d464dcf8e987d4892d09425:u_3c3d38f163bc442f82e8e5ef143def8d | migrated | d980b79243546a13d73f84d53a6c2fc2 | - |
| direct_message | a520aa7d-36e7-407b-8bc8-483ce851b19e | single:u_1f4cafda6d464dcf8e987d4892d09425:u_6a367a3c9c5e437ab5fd5cdca84d8a35 | failed | - | RecordNotFoundError |
| direct_message | c3d5a897-6a23-4b9f-bbda-e977acacd7d8 | single:u_1f4cafda6d464dcf8e987d4892d09425:u_6bfc321407094cbab77e1f21781bee33 | migrated | cf7ff787213792393239db2d2216421b | - |
| direct_message | 573b57e5-b4c4-4a81-ab7a-f55853542214 | single:u_1f4cafda6d464dcf8e987d4892d09425:u_6bfc321407094cbab77e1f21781bee33 | migrated | f77f205779a28b0d6922fb5d5f1523db | - |
| direct_message | c4f1ce69-0e83-40ff-a8a8-f4f2895bafb2 | single:u_1f4cafda6d464dcf8e987d4892d09425:u_6bfc321407094cbab77e1f21781bee33 | migrated | afa9e3c91d272bcec83dc5134a13d51b | - |
| direct_message | 7039ef55-e87f-4057-9867-7d9f6020ac26 | single:u_1f4cafda6d464dcf8e987d4892d09425:u_6bfc321407094cbab77e1f21781bee33 | migrated | 27e5add50f825e96deb426a4d412ac50 | - |
| direct_message | 51602a6b-8cf6-4b36-b36a-546064f82b5f | single:u_1f4cafda6d464dcf8e987d4892d09425:u_84c6bd4bde064ae684caf71ad163e909 | failed | - | RecordNotFoundError |
| direct_message | bf50d416-37ae-4a03-bbdf-b75419b69fca | single:u_322a63f985ba43df8594552ad532968c:u_6bfc321407094cbab77e1f21781bee33 | failed | - | RecordNotFoundError |
| direct_message | b157200b-1aad-4092-90c0-f8ef8f159d7f | single:u_3c3d38f163bc442f82e8e5ef143def8d:u_6bfc321407094cbab77e1f21781bee33 | migrated | 33d12e810bbf58d0d2c5c640c4742b52 | - |
| direct_message | dab6d8b9-82ba-487d-9d45-8ec56157d3ad | single:u_6bfc321407094cbab77e1f21781bee33:u_e9bfb9c2479b4cd3b4b4a4dd0c81e070 | migrated | 9b9efb8cad410e4e2dee618421b4bc2a | - |
| direct_message | 2a1f29f3-82c8-4e72-843c-09482abc9db2 | single:u_91402b9a7f514be5a8741354dc93a15e:u_c77c1b51c40144c5a923a1e168f2191b | failed | - | RecordNotFoundError |
| direct_message | 75f0c6fb-a7dd-4079-aa2b-f527b74b911f | single:u_91402b9a7f514be5a8741354dc93a15e:u_c77c1b51c40144c5a923a1e168f2191b | failed | - | RecordNotFoundError |
| direct_message | 37e1191e-a8e0-43a8-8b36-cfba0491decd | single:u_91402b9a7f514be5a8741354dc93a15e:u_c77c1b51c40144c5a923a1e168f2191b | failed | - | RecordNotFoundError |
| direct_message | 182bf540-310c-4d3e-9b9b-a69b8122c50c | single:u_9e549a45fe9846148a29be0d668f0872:u_a33be950b8024df59a36358b9f2b0522 | failed | - | RecordNotFoundError |

## 3. 下一步

- 检查 failed/skipped 行，修复后重新执行同一脚本。
