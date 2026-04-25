# Raver 本地开发：代理与数据库操作手册

本文档用于统一说明：
- 如何在本地分别以「挂代理 / 不挂代理」方式启动服务
- 如何启动 `festival-viewer` 依赖的后端服务（`scrapRave/web_tool/server.py`）
- 数据库结构变化后（Prisma）的标准操作流程

## 1. 服务与端口总览

- App 后端（Node/Express）：`http://127.0.0.1:3901`
- Web 前端（Next.js）：`http://127.0.0.1:3000`
- Festival Viewer 后端（Python）：`http://127.0.0.1:8000`
- Postgres：`127.0.0.1:5432`
- Redis：`127.0.0.1:6379`

## 2. 代理环境变量约定（Clash 7897）

建议统一使用以下环境变量：

```bash
export HTTP_PROXY=http://127.0.0.1:7897
export HTTPS_PROXY=http://127.0.0.1:7897
export ALL_PROXY=socks5://127.0.0.1:7897
export NO_PROXY=127.0.0.1,localhost
export no_proxy=127.0.0.1,localhost
```

取消代理（当前终端）：

```bash
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY no_proxy
```

## 3. 启动数据库

在项目根目录执行：

```bash
cd /Users/blackie/Projects/raver
docker-compose up -d
```

查看状态：

```bash
docker-compose ps
```

## 4. 启动 App 后端（server）

### 4.1 不挂代理

```bash
cd /Users/blackie/Projects/raver/server
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY no_proxy
pnpm dev
```

健康检查：

```bash
curl http://127.0.0.1:3901/health
```

### 4.2 挂 Clash 代理（7897）

```bash
cd /Users/blackie/Projects/raver/server
export HTTP_PROXY=http://127.0.0.1:7897
export HTTPS_PROXY=http://127.0.0.1:7897
export ALL_PROXY=socks5://127.0.0.1:7897
export NO_PROXY=127.0.0.1,localhost
export no_proxy=127.0.0.1,localhost
pnpm dev
```

说明：
- `server/package.json` 的 `dev/start` 已启用 `NODE_OPTIONS='--use-env-proxy'`
- 只要你设置了上面的 `HTTP_PROXY/HTTPS_PROXY`，Node 请求会按环境代理走

## 5. 启动 Web 前端（web）

### 5.1 不挂代理

```bash
cd /Users/blackie/Projects/raver/web
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY no_proxy
pnpm dev
```

### 5.2 挂 Clash 代理（7897）

```bash
cd /Users/blackie/Projects/raver/web
export HTTP_PROXY=http://127.0.0.1:7897
export HTTPS_PROXY=http://127.0.0.1:7897
export ALL_PROXY=socks5://127.0.0.1:7897
export NO_PROXY=127.0.0.1,localhost
export no_proxy=127.0.0.1,localhost
pnpm dev
```

## 6. 启动 Festival Viewer 后端（web_tool）

`festival-viewer.html` 不是直接 `file://` 打开就能完整工作的页面；地图配置、BFF 代理接口来自 `web_tool/server.py`。

### 6.1 不挂代理

```bash
cd /Users/blackie/Projects/raver/scrapRave
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY no_proxy
python3 web_tool/server.py
```

### 6.2 挂 Clash 代理（7897）

```bash
cd /Users/blackie/Projects/raver/scrapRave
export HTTP_PROXY=http://127.0.0.1:7897
export HTTPS_PROXY=http://127.0.0.1:7897
export ALL_PROXY=socks5://127.0.0.1:7897
export NO_PROXY=127.0.0.1,localhost
export no_proxy=127.0.0.1,localhost
python3 web_tool/server.py
```

说明：
- 默认监听 `127.0.0.1:8000`
- 会自动读取 `scrapRave/.env.local`
- 关键接口：`http://127.0.0.1:8000/api/viewer/runtime-config`

## 7. 推荐启动顺序（避免联调问题）

1. 启动数据库：`docker-compose up -d`
2. 启动 app 后端：`server/pnpm dev`
3. 启动 web_tool：`python3 scrapRave/web_tool/server.py`
4. 启动 web 前端：`web/pnpm dev`

## 8. Prisma：数据库变更后的标准操作

以下流程适用于你修改了 `server/prisma/schema.prisma` 之后。

### 8.1 本地开发推荐流程（有 migration）

```bash
cd /Users/blackie/Projects/raver/server
pnpm prisma:migrate --name <migration_name>
pnpm prisma:generate
```

建议：
- `migration_name` 用英文 snake_case，例如：`add_event_city_i18n`
- 执行后确认新目录已出现在 `server/prisma/migrations/`

### 8.2 仅同步模型（临时开发，不推荐长期）

```bash
cd /Users/blackie/Projects/raver/server
npx prisma db push
pnpm prisma:generate
```

说明：
- `db push` 不会生成 migration 历史
- 团队协作/可回滚场景优先用 `migrate dev`

### 8.3 拉到别人新 migration 后

```bash
cd /Users/blackie/Projects/raver/server
pnpm install
npx prisma migrate dev
pnpm prisma:generate
```

### 8.4 需要重建本地库（高风险，会清空数据）

```bash
cd /Users/blackie/Projects/raver/server
npx prisma migrate reset
pnpm prisma:generate
```

如需种子数据：

```bash
pnpm prisma:seed
```

## 9. 常见问题与快速排查

### 9.1 报错：数据库缺字段（例如 `events.manual_location does not exist`）

原因：代码已读取新字段，但本地数据库未执行对应 migration。  
处理：

```bash
cd /Users/blackie/Projects/raver/server
npx prisma migrate dev
pnpm prisma:generate
```

### 9.2 `festival-viewer` 地图配置读取失败 / CORS / `file://` 问题

原因：直接打开 `file:///.../festival-viewer.html`，无法访问 `http://127.0.0.1:8000/api/viewer/runtime-config`。  
处理：
- 必须先启动 `python3 web_tool/server.py`
- 用 `http://127.0.0.1:8000/...` 方式访问页面（不要直接 `file://`）

### 9.3 端口占用

```bash
lsof -iTCP:3000 -sTCP:LISTEN
lsof -iTCP:3901 -sTCP:LISTEN
lsof -iTCP:8000 -sTCP:LISTEN
```

按 PID 结束进程：

```bash
kill <PID>
```

## 10. 一键命令参考

项目已有快捷脚本（按需使用）：
- `/Users/blackie/Projects/raver/start-all.sh`：启动 3000/3901
- `/Users/blackie/Projects/raver/restart-dev.sh`：清理并重启 3000/3901

注意：
- 这两个脚本默认不处理 `web_tool:8000`
- 若要跑 `festival-viewer`，仍需单独起 `python3 web_tool/server.py`

## 11. APNs 本地联调入口

APNs 真机联调请直接看：

- `docs/APNS_REAL_DEVICE_SETUP_AND_E2E_RUNBOOK.md`

最小检查命令：

```bash
# 1) 查看 APNs 配置状态（enabled/configured 是否为 true）
curl -sS "http://localhost:3901/v1/notification-center/admin/status?windowHours=24" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.status.apns'

# 2) 发布测试通知（in_app + apns）
curl -sS -X POST http://localhost:3901/v1/notification-center/admin/publish-test \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "category":"major_news",
    "title":"APNs Smoke",
    "message":"hello from raver",
    "channels":["in_app","apns"],
    "targetUserIds":["<target-user-id>"]
  }' | jq .
```

## 12. Outbox 灰度验证（异步派发）

用于验证 `NOTIFICATION_OUTBOX_ASYNC_ENABLED=true` 后，投递是否按 `queued -> sent/failed` 正常推进。

### 12.1 开启异步模式（测试环境）

在 `server/.env` 设置：

```env
NOTIFICATION_OUTBOX_ASYNC_ENABLED=true
NOTIFICATION_OUTBOX_WORKER_ENABLED=true
NOTIFICATION_OUTBOX_WORKER_INTERVAL_MS=5000
NOTIFICATION_OUTBOX_WORKER_EVENT_LIMIT=20
```

重启服务后执行：

```bash
cd /Users/blackie/Projects/raver/server
pnpm notification:outbox:gray-verify
```

### 12.2 判定规则

- `PASS`：脚本末尾输出 `result=PASS`
- `FAIL`：脚本末尾输出 `result=FAIL`，并打印失败原因（例如未返回 `queued-for-worker`、队列卡住、分发未终态）

默认会检查：
- 发布结果里非 `in_app` 渠道是否返回 `queued-for-worker`
- 轮询 `admin/deliveries`，确认没有长期 `queued`
- `in_app` 至少 `sent`
- `apns` 进入终态（`sent` 或带错误的 `failed`）
- `admin/status` 中无 queue stuck 告警

## 13. APNs 上线检查清单 + 回滚 SOP

适用场景：
- 准备将 APNs 能力切到线上或预发环境
- 希望值班同学可按固定步骤快速判断是否可放量

### 13.1 可复制执行：上线前检查

```bash
# ===== 0) 基础变量（按实际替换）=====
export BASE_URL="http://localhost:3901"
export ADMIN_USER="uploadtester"
read -s -p "ADMIN_PASS: " ADMIN_PASS; echo
export TARGET_USER_ID="1f4cafda-6d46-4dcf-8e98-7d4892d09425"

# ===== 1) 登录拿管理员 token =====
export ADMIN_TOKEN=$(curl -sS -X POST "$BASE_URL/v1/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASS\"}" | jq -r '.token')

test "$ADMIN_TOKEN" != "null" && test -n "$ADMIN_TOKEN" && echo "[PASS] ADMIN_TOKEN OK" || (echo "[FAIL] login failed"; exit 1)

# ===== 2) APNs 配置健康检查 =====
curl -sS "$BASE_URL/v1/notification-center/admin/status?windowHours=24" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.status.apns'

# ===== 3) 发布 smoke test（in_app + apns）=====
curl -sS -X POST "$BASE_URL/v1/notification-center/admin/publish-test" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
    \"category\":\"major_news\",
    \"title\":\"APNs Release Smoke\",
    \"message\":\"smoke from release checklist\",
    \"channels\":[\"in_app\",\"apns\"],
    \"targetUserIds\":[\"$TARGET_USER_ID\"]
  }" | jq .

# ===== 4) 查看最近投递结果 =====
curl -sS "$BASE_URL/v1/notification-center/admin/deliveries?limit=20&userId=$TARGET_USER_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.items'
```

通过标准（手工确认）：
- `status.apns.enabled=true`
- `status.apns.configured=true`
- `status.apns.missingConfig=[]`
- 最近 `apns` 记录 `status=sent` 且 `error=null`
- 最近 `in_app` 记录 `status=sent`

### 13.2 上线后 30 分钟观测（每 5 分钟执行一次）

```bash
# APNs 健康状态
curl -sS "$BASE_URL/v1/notification-center/admin/status?windowHours=1" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.status.apns'

# 最近 200 条 APNs 失败率
curl -sS "$BASE_URL/v1/notification-center/admin/deliveries?limit=200" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
| jq '[.items[] | select(.channel=="apns")] as $a
      | {total: ($a|length),
         failed: ($a|map(select(.status=="failed"))|length),
         fail_rate: (if ($a|length)==0 then 0 else ((($a|map(select(.status=="failed"))|length) / ($a|length)) * 100) end)}'
```

建议判定阈值：
1. `fail_rate <= 2%`：继续灰度/放量
2. `2% < fail_rate <= 5%`：暂停放量，开始人工排查
3. `fail_rate > 5%` 且连续 10 分钟：执行回滚 SOP

### 13.3 回滚 SOP（从小到大）

#### L1：只关 Outbox Worker（队列异常）

操作：
1. 设置 `NOTIFICATION_OUTBOX_WORKER_ENABLED=false`
2. 重启 server 进程
3. 观察 10 分钟失败率变化

#### L2：关闭异步投递（改回同步）

操作：
1. 设置 `NOTIFICATION_OUTBOX_ASYNC_ENABLED=false`
2. 保持 `NOTIFICATION_APNS_ENABLED=true`
3. 重启 server
4. 重新执行一次 smoke test，确认 `apns=sent`

#### L3：关闭 APNs，只保留站内通知

操作：
1. 设置 `NOTIFICATION_APNS_ENABLED=false`
2. 重启 server
3. 发布 `publish-test`，确认 `in_app=sent` 且 APNs 不再发送

回滚完成标准：
1. `admin/status` 正常，无配置缺失
2. `admin/deliveries` 无持续性异常增长
3. 用户核心通知链路（`in_app`）可用

### 13.4 上线当日最低动作建议

1. 先小流量灰度（内部账号/白名单账号）
2. 观察 30 分钟再全量
3. 全量后继续观察 1-2 小时
4. 故障时严格按 L1 -> L2 -> L3 执行，不要跨级跳过
