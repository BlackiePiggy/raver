# OpenIM 历史消息迁移执行报告

- 运行时间：2026-04-21T08:49:01.556Z ~ 2026-04-21T08:49:01.594Z
- 执行发送：否（plan only）
- OpenIM enabled：true
- sourceType：all
- batchSize：50
- maxMessages：500
- failFast：false

## 1. 执行摘要

| scannedRows | directRows | squadRows | planned | migrated | failed | skipped |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 25 | 16 | 9 | 25 | 0 | 0 | 0 |

## 2. 样本

| sourceType | sourceId | conversationKey | status | targetMessageId | error |
| --- | --- | --- | --- | --- | --- |
| squad_message | f77bef61-f810-4ae0-910c-55097442f7a6 | group:g_5dc1e254f0d5452ba32d209890d07378 | planned | - | - |
| squad_message | 9d69316f-1e54-4fba-bedb-41ab83de2b62 | group:g_6379f4a61b5944b298f1dc961a8119e9 | planned | - | - |
| squad_message | 59440392-fb46-45b8-b2d0-e3005df2e02d | group:g_b63ea9df6dee445eac4979be92572080 | planned | - | - |
| squad_message | 442aa3ec-d513-4702-859f-a66f731ff301 | group:g_b63ea9df6dee445eac4979be92572080 | planned | - | - |
| squad_message | 727c93a4-e326-4188-a4f6-eb106e05eb59 | group:g_bb04874d61724a20b79b9aeb952c4cce | planned | - | - |
| squad_message | a9c47041-dc0f-449d-abd9-0ff6281c7b39 | group:g_bb04874d61724a20b79b9aeb952c4cce | planned | - | - |
| squad_message | 215c429a-5c08-43aa-a8bd-e8194c6fed3d | group:g_bb04874d61724a20b79b9aeb952c4cce | planned | - | - |
| squad_message | d8ff28a2-4655-4fa0-80dd-f6f032798b91 | group:g_da057f973c0a492d8973a02c961b1ca1 | planned | - | - |
| squad_message | d48fc772-7ee4-4d6d-bf11-316a6c221de1 | group:g_da057f973c0a492d8973a02c961b1ca1 | planned | - | - |
| direct_message | 2b320d36-9077-4526-ab84-a5f11a2e29ed | single:u_0fcba61a6bf340108e33981ed7a2b0e0:u_6bfc321407094cbab77e1f21781bee33 | planned | - | - |
| direct_message | d8ad04ed-5406-4135-9097-38a48d52ef50 | single:u_1f4cafda6d464dcf8e987d4892d09425:u_322a63f985ba43df8594552ad532968c | planned | - | - |
| direct_message | 0000f9af-95bd-4494-8691-1c1e3d94f9fe | single:u_1f4cafda6d464dcf8e987d4892d09425:u_3c3d38f163bc442f82e8e5ef143def8d | planned | - | - |
| direct_message | a520aa7d-36e7-407b-8bc8-483ce851b19e | single:u_1f4cafda6d464dcf8e987d4892d09425:u_6a367a3c9c5e437ab5fd5cdca84d8a35 | planned | - | - |
| direct_message | c3d5a897-6a23-4b9f-bbda-e977acacd7d8 | single:u_1f4cafda6d464dcf8e987d4892d09425:u_6bfc321407094cbab77e1f21781bee33 | planned | - | - |
| direct_message | 573b57e5-b4c4-4a81-ab7a-f55853542214 | single:u_1f4cafda6d464dcf8e987d4892d09425:u_6bfc321407094cbab77e1f21781bee33 | planned | - | - |
| direct_message | c4f1ce69-0e83-40ff-a8a8-f4f2895bafb2 | single:u_1f4cafda6d464dcf8e987d4892d09425:u_6bfc321407094cbab77e1f21781bee33 | planned | - | - |
| direct_message | 7039ef55-e87f-4057-9867-7d9f6020ac26 | single:u_1f4cafda6d464dcf8e987d4892d09425:u_6bfc321407094cbab77e1f21781bee33 | planned | - | - |
| direct_message | 51602a6b-8cf6-4b36-b36a-546064f82b5f | single:u_1f4cafda6d464dcf8e987d4892d09425:u_84c6bd4bde064ae684caf71ad163e909 | planned | - | - |
| direct_message | bf50d416-37ae-4a03-bbdf-b75419b69fca | single:u_322a63f985ba43df8594552ad532968c:u_6bfc321407094cbab77e1f21781bee33 | planned | - | - |
| direct_message | b157200b-1aad-4092-90c0-f8ef8f159d7f | single:u_3c3d38f163bc442f82e8e5ef143def8d:u_6bfc321407094cbab77e1f21781bee33 | planned | - | - |
| direct_message | dab6d8b9-82ba-487d-9d45-8ec56157d3ad | single:u_6bfc321407094cbab77e1f21781bee33:u_e9bfb9c2479b4cd3b4b4a4dd0c81e070 | planned | - | - |
| direct_message | 2a1f29f3-82c8-4e72-843c-09482abc9db2 | single:u_91402b9a7f514be5a8741354dc93a15e:u_c77c1b51c40144c5a923a1e168f2191b | planned | - | - |
| direct_message | 75f0c6fb-a7dd-4079-aa2b-f527b74b911f | single:u_91402b9a7f514be5a8741354dc93a15e:u_c77c1b51c40144c5a923a1e168f2191b | planned | - | - |
| direct_message | 37e1191e-a8e0-43a8-8b36-cfba0491decd | single:u_91402b9a7f514be5a8741354dc93a15e:u_c77c1b51c40144c5a923a1e168f2191b | planned | - | - |
| direct_message | 182bf540-310c-4d3e-9b9b-a69b8122c50c | single:u_9e549a45fe9846148a29be0d668f0872:u_a33be950b8024df59a36358b9f2b0522 | planned | - | - |

## 3. 下一步

- 当前为 plan only。确认样本无误后，使用 `pnpm openim:migration:execute` 执行真实发送。
