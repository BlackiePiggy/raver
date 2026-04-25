# OpenIM 本地验证 Runbook

> 目标：完成 OpenIM Phase 0，本地跑通 OpenIM 服务、Raver 后端 OpenIM bootstrap、用户注册和 token 获取。  
> 当前策略：使用 OpenIM 官方 `openimsdk/openim-docker`，不在 Raver 仓库复制官方 compose，避免版本漂移。

## 1. 前置条件

- Docker Desktop 或 Docker Engine
- Docker Compose v2，即 `docker compose`
- Node/pnpm 已可运行 Raver server
- 本地 Raver Postgres/Redis 可用
- 至少一个 Raver 测试用户

官方 Docker 部署文档：

- https://docs.openim.io/guides/gettingstarted/dockercompose
- https://github.com/openimsdk/openim-docker

## 2. 拉取 OpenIM Docker 部署仓库

建议放在 Raver 仓库外，避免把 OpenIM 官方部署文件混进业务仓库：

```bash
mkdir -p ~/Projects/vendor
cd ~/Projects/vendor
git clone https://github.com/openimsdk/openim-docker
cd openim-docker
```

建议切到 GitHub Releases 页面带 Latest 标记的版本。官方文档建议使用最新稳定 release tag。

## 3. 配置 OpenIM `.env`

编辑 `~/Projects/vendor/openim-docker/.env`。

本地验证至少确认：

```dotenv
MINIO_EXTERNAL_ADDRESS="http://127.0.0.1:10005"
```

如果你希望 iOS 真机访问，而不是模拟器访问，需要把 `127.0.0.1` 换成 Mac 局域网 IP，例如：

```dotenv
MINIO_EXTERNAL_ADDRESS="http://192.168.1.10:10005"
```

同理，Raver 的 `OPENIM_API_BASE_URL` 和 `OPENIM_WS_URL` 也要使用真机可访问地址。

如果你希望“服务端继续走本机回环地址（127.0.0.1）”但“客户端拿到局域网地址”，可使用：

```dotenv
OPENIM_API_BASE_URL=http://127.0.0.1:10002
OPENIM_WS_URL=ws://127.0.0.1:10001
OPENIM_CLIENT_API_BASE_URL=http://<你的Mac局域网IP>:10002
OPENIM_CLIENT_WS_URL=ws://<你的Mac局域网IP>:10001
```

> iOS 端兜底（新增）：`RaverMVP` 在**模拟器**下会默认把 bootstrap 里的 OpenIM host 归一化为 `127.0.0.1`，避免 LAN IP 在 simulator 上抖动（`host is down / i/o timeout`）。  
> 如需关闭该行为，可在 Xcode Scheme Environment Variables 设置：
>
> ```dotenv
> RAVER_OPENIM_SIMULATOR_FORCE_LOCALHOST=false
> ```

## 4. 启动 OpenIM

```bash
cd ~/Projects/vendor/openim-docker
docker compose up -d
```

首次启动会拉取较大的镜像。官方文档建议启动后等待 `30-60s` 再检查。

查看日志：

```bash
docker compose logs -f openim-server openim-chat
```

停止服务：

```bash
docker compose down
```

## 5. 常见容器冲突

OpenIM 官方 compose 默认可能使用固定 `container_name`。如果本机已有以下同名容器，`docker compose up -d` 可能失败：

```text
mongo
redis
kafka
etcd
minio
openim-server
openim-chat
```

处理方式：

1. 停掉冲突容器。
2. 或使用干净的 Docker 环境。
3. 或修改 OpenIM 官方 compose，但这会增加后续升级成本。

## 6. 配置 Raver Server 环境变量

不要直接提交真实 secret。可以参考：

- `server/.env.openim.example`

本地最小配置：

```dotenv
OPENIM_ENABLED=true
OPENIM_API_BASE_URL=http://127.0.0.1:10002
OPENIM_WS_URL=ws://127.0.0.1:10001
OPENIM_CLIENT_API_BASE_URL=
OPENIM_CLIENT_WS_URL=
OPENIM_ADMIN_USER_ID=imAdmin
OPENIM_ADMIN_SECRET=replace_with_openim_secret
OPENIM_PLATFORM_ID=1
OPENIM_SYSTEM_USER_ID=raver_system
OPENIM_SYNC_WORKER_ENABLED=true
OPENIM_SYNC_WORKER_INTERVAL_MS=5000
OPENIM_SYNC_WORKER_BATCH_SIZE=20
OPENIM_SYNC_LOCK_TIMEOUT_MS=60000
OPENIM_SYNC_DEFAULT_MAX_ATTEMPTS=5
OPENIM_WEBHOOK_SECRET=replace_with_openim_webhook_secret
OPENIM_WEBHOOK_REQUIRE_SIGNATURE=true
OPENIM_WEBHOOK_TOLERANCE_SECONDS=300
OPENIM_WEBHOOK_BLOCK_SENSITIVE_WORDS=false
OPENIM_SENSITIVE_WORDS=
OPENIM_SENSITIVE_PATTERNS=
OPENIM_WEBHOOK_BLOCK_IMAGE_HITS=false
OPENIM_IMAGE_MODERATION_ENABLED=true
OPENIM_IMAGE_MODERATION_BLOCK_KEYWORDS=
OPENIM_IMAGE_MODERATION_ALLOWED_HOSTS=
OPENIM_IMAGE_MODERATION_MAX_URLS=10
```

如果 OpenIM 当前版本 REST path 和默认值不一致，可以覆盖：

```dotenv
OPENIM_PATH_GET_ADMIN_TOKEN=/auth/get_admin_token
OPENIM_PATH_GET_USER_TOKEN=/auth/get_user_token
OPENIM_PATH_USER_REGISTER=/user/user_register
OPENIM_PATH_UPDATE_USER_INFO=/user/update_user_info_ex
OPENIM_PATH_CREATE_GROUP=/group/create_group
OPENIM_PATH_SEND_MESSAGE=/msg/send_msg
OPENIM_PATH_REVOKE_MESSAGE=/msg/revoke_msg
OPENIM_PATH_DELETE_MESSAGE=/msg/delete_msg
```

## 7. 运行 Raver OpenIM 冒烟脚本

先只测试 admin token：

```bash
cd /Users/blackie/Projects/raver/server
OPENIM_ENABLED=true pnpm openim:smoke
```

测试指定 Raver 用户 bootstrap：

```bash
cd /Users/blackie/Projects/raver/server
OPENIM_ENABLED=true OPENIM_SMOKE_USER_ID=<raver_user_id> pnpm openim:smoke
```

可选：测试创建 3 人群。

```bash
cd /Users/blackie/Projects/raver/server
OPENIM_ENABLED=true \
OPENIM_SMOKE_CREATE_GROUP=true \
OPENIM_SMOKE_GROUP_OWNER_ID=<owner_user_id> \
OPENIM_SMOKE_GROUP_MEMBER_IDS=<member_user_id_1>,<member_user_id_2> \
pnpm openim:smoke
```

注意：创建群会在 OpenIM 里留下测试群。请使用测试账号。

## 8. 验证 Raver API

启动 Raver server：

```bash
cd /Users/blackie/Projects/raver/server
pnpm dev
```

登录 Raver 获取 JWT 后：

```bash
curl -H "Authorization: Bearer <raver_jwt>" \
  http://localhost:3901/v1/openim/bootstrap
```

期望响应：

```json
{
  "enabled": true,
  "userID": "...",
  "token": "...",
  "apiURL": "http://127.0.0.1:10002",
  "wsURL": "ws://127.0.0.1:10001",
  "platformID": 1,
  "systemUserID": "raver_system",
  "expiresAt": "..."
}
```

如果 `OPENIM_ENABLED=false`，接口会返回 disabled bootstrap，不会访问 OpenIM：

```json
{
  "enabled": false,
  "token": null
}
```

本地 webhook 验签/落库验证（`OPENIM_WEBHOOK_SECRET` 未配置时）：

```bash
curl -X POST http://localhost:3901/v1/openim/webhooks \
  -H "Content-Type: application/json" \
  -d '{"callbackCommand":"test.before_send","operationID":"op_local_1","eventID":"evt_local_1","data":{"content":"hello world"}}'
```

期望响应：

```json
{ "errCode": 0, "errMsg": "" }
```

并可在数据库 `openim_webhook_events` 表中看到对应记录。

本地图片审核任务验证（已开启 `OPENIM_IMAGE_MODERATION_ENABLED=true`）：

```bash
curl -X POST http://localhost:3901/v1/openim/webhooks \
  -H "Content-Type: application/json" \
  -d '{"callbackCommand":"msg.before_send","operationID":"op_local_img_1","messageID":"msg_local_img_1","conversationID":"si_test","data":{"imageURL":"https://cdn.raverapp.com/chat/demo.jpg"}}'
```

期望：

- 返回 `{"errCode":0,"errMsg":""}`（默认不拦截）；
- `openim_image_moderation_jobs` 表新增 `pending` 记录；
- 管理端可通过 `GET /v1/openim/admin/image-moderation/jobs` 查看任务。

## 9. Phase 0 验收标准

- [ ] OpenIM Docker 服务启动成功。
- [ ] `openim-server` 和 `openim-chat` 日志无持续报错。
- [ ] `pnpm openim:smoke` 能获取 admin token。
- [ ] 指定 Raver 用户后，脚本能完成用户注册和 user token 获取。
- [ ] `/v1/openim/bootstrap` 能返回 iOS SDK 所需配置。
- [ ] 可选创建 3 人测试群成功。

## 10. 历史消息迁移 dry-run

执行全量 dry-run（默认不写入迁移状态表）：

```bash
cd /Users/blackie/Projects/raver/server
pnpm openim:migration:dry-run
```

仅扫描私信：

```bash
cd /Users/blackie/Projects/raver/server
pnpm openim:migration:dry-run:direct
```

仅扫描小队群聊：

```bash
cd /Users/blackie/Projects/raver/server
pnpm openim:migration:dry-run:squad
```

写入 `openim_message_migrations` 待迁移基线（仍不调用 OpenIM 发送）：

```bash
cd /Users/blackie/Projects/raver/server
OPENIM_MIGRATION_DRYRUN_PERSIST=true pnpm openim:migration:dry-run
```

默认报告输出目录：

```text
docs/reports/openim-migration-dryrun-*.md
```

## 11. 历史消息迁移执行器

先生成待迁移基线：

```bash
cd /Users/blackie/Projects/raver/server
OPENIM_MIGRATION_DRYRUN_PERSIST=true pnpm openim:migration:dry-run
```

预览将要执行的 pending 迁移，不调用 OpenIM：

```bash
cd /Users/blackie/Projects/raver/server
pnpm openim:migration:plan
```

真实执行迁移，调用 OpenIM `send_msg` 并回写 `openim_message_migrations`：

```bash
cd /Users/blackie/Projects/raver/server
OPENIM_ENABLED=true pnpm openim:migration:execute
```

常用限制：

```bash
OPENIM_MIGRATION_SOURCE_TYPE=direct_message
OPENIM_MIGRATION_EXECUTE_BATCH_SIZE=20
OPENIM_MIGRATION_EXECUTE_MAX_MESSAGES=100
OPENIM_MIGRATION_FAIL_FAST=true
OPENIM_MIGRATION_INCLUDE_FAILED=true
```

默认报告输出目录：

```text
docs/reports/openim-migration-execute-*.md
```

## 12. 小队 Group Reconcile

如果 `SquadMessage` 迁移出现 `RecordNotFoundError`，通常说明 OpenIM 中缺少对应 group。先预览：

```bash
cd /Users/blackie/Projects/raver/server
pnpm openim:squad:reconcile:plan
```

执行修复：

```bash
cd /Users/blackie/Projects/raver/server
OPENIM_ENABLED=true pnpm openim:squad:reconcile
```

修复后重跑小队消息迁移：

```bash
cd /Users/blackie/Projects/raver/server
OPENIM_MIGRATION_SOURCE_TYPE=squad_message \
OPENIM_MIGRATION_INCLUDE_FAILED=true \
OPENIM_MIGRATION_EXECUTE_BATCH_SIZE=20 \
pnpm openim:migration:execute
```

历史 1 人/2 人小队无法直接创建 OpenIM group；执行器会将这些消息标记为 `skipped`，避免反复失败。

## 13. 本地压测

默认压测：

```bash
cd /Users/blackie/Projects/raver
OPENIM_ENABLED=true pnpm -C server openim:load-test
```

较高本地 burst：

```bash
cd /Users/blackie/Projects/raver
OPENIM_ENABLED=true \
OPENIM_LOAD_TEST_USERS=100 \
OPENIM_LOAD_TEST_DIRECT_MESSAGES=1000 \
OPENIM_LOAD_TEST_GROUP_MESSAGES=1000 \
OPENIM_LOAD_TEST_GROUP_SIZE=100 \
OPENIM_LOAD_TEST_CONCURRENCY=50 \
pnpm -C server openim:load-test
```

默认报告输出目录：

```text
docs/reports/openim-load-test-*.md
```

已完成的本地验证：

- 200 条消息 / 10 并发 / 0 失败；
- 1000 条消息 / 25 并发 / 0 失败；
- 2000 条消息 / 50 并发 / 100 人群 / 0 失败。

详细方案与结果见：

[docs/OPENIM_LOAD_TEST_PLAN.md](/Users/blackie/Projects/raver/docs/OPENIM_LOAD_TEST_PLAN.md)

注意：当前压测验证的是 OpenIM REST `send_msg` 发消息链路，不等价于 1000 个 iOS/OpenIM WebSocket 客户端同时在线。生产前仍需补 1k 在线连接 soak test。

## 14. 下一步

Phase 0 通过后进入：

1. iOS 增加 `OpenIMBootstrapService`，先只拉 `/v1/openim/bootstrap`。
2. 验证 OpenIM iOS SDK 依赖接入方式，优先 SPM，其次 CocoaPods。
3. 用 3 个测试用户完成单聊和小队群聊 SDK demo。
