# OpenIM 历史消息迁移执行报告

- 运行时间：2026-04-21T08:55:39.294Z ~ 2026-04-21T08:55:39.411Z
- 执行发送：是
- OpenIM enabled：true
- sourceType：direct_message
- batchSize：20
- maxMessages：20
- failFast：false
- includeFailed：true

## 1. 执行摘要

| scannedRows | directRows | squadRows | planned | migrated | failed | skipped |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 8 | 8 | 0 | 0 | 8 | 0 | 0 |

## 2. 样本

| sourceType | sourceId | conversationKey | status | targetMessageId | error |
| --- | --- | --- | --- | --- | --- |
| direct_message | d8ad04ed-5406-4135-9097-38a48d52ef50 | single:u_1f4cafda6d464dcf8e987d4892d09425:u_322a63f985ba43df8594552ad532968c | migrated | 8b89eb59bb032ecf10e72ca26ad84190 | - |
| direct_message | a520aa7d-36e7-407b-8bc8-483ce851b19e | single:u_1f4cafda6d464dcf8e987d4892d09425:u_6a367a3c9c5e437ab5fd5cdca84d8a35 | migrated | fafffb9043dffa2928c8a2462e1d788e | - |
| direct_message | 51602a6b-8cf6-4b36-b36a-546064f82b5f | single:u_1f4cafda6d464dcf8e987d4892d09425:u_84c6bd4bde064ae684caf71ad163e909 | migrated | 0c6916deddc7710d3d6c3535ff092dd6 | - |
| direct_message | bf50d416-37ae-4a03-bbdf-b75419b69fca | single:u_322a63f985ba43df8594552ad532968c:u_6bfc321407094cbab77e1f21781bee33 | migrated | 5bb09299b0065426e26fe0ea24282c1a | - |
| direct_message | 2a1f29f3-82c8-4e72-843c-09482abc9db2 | single:u_91402b9a7f514be5a8741354dc93a15e:u_c77c1b51c40144c5a923a1e168f2191b | migrated | 6e13974f93daea7e82fd62b08b6ee6b4 | - |
| direct_message | 75f0c6fb-a7dd-4079-aa2b-f527b74b911f | single:u_91402b9a7f514be5a8741354dc93a15e:u_c77c1b51c40144c5a923a1e168f2191b | migrated | 83bf294c1dafd80588228f7c6d014125 | - |
| direct_message | 37e1191e-a8e0-43a8-8b36-cfba0491decd | single:u_91402b9a7f514be5a8741354dc93a15e:u_c77c1b51c40144c5a923a1e168f2191b | migrated | 4a765029ed9a5ee6f44c3ce0e890ee28 | - |
| direct_message | 182bf540-310c-4d3e-9b9b-a69b8122c50c | single:u_9e549a45fe9846148a29be0d668f0872:u_a33be950b8024df59a36358b9f2b0522 | migrated | af3db92e5f00bd2713a03704b53a2ced | - |

## 3. 下一步

- 检查 failed/skipped 行，修复后重新执行同一脚本。
