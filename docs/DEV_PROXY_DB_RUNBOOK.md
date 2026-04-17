# Raver 本地开发：代理与数据库操作手册

本文档用于统一说明：
- 如何在本地分别以「挂代理 / 不挂代理」方式启动服务
- 如何启动 `festival-viewer` 依赖的后端服务（`scrapRave/web_tool/server.py`）
- 数据库结构变化后（Prisma）的标准操作流程

## 1. 服务与端口总览

- App 后端（Node/Express）：`http://127.0.0.1:3001`
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
curl http://127.0.0.1:3001/health
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
lsof -iTCP:3001 -sTCP:LISTEN
lsof -iTCP:8000 -sTCP:LISTEN
```

按 PID 结束进程：

```bash
kill <PID>
```

## 10. 一键命令参考

项目已有快捷脚本（按需使用）：
- `/Users/blackie/Projects/raver/start-all.sh`：启动 3000/3001
- `/Users/blackie/Projects/raver/restart-dev.sh`：清理并重启 3000/3001

注意：
- 这两个脚本默认不处理 `web_tool:8000`
- 若要跑 `festival-viewer`，仍需单独起 `python3 web_tool/server.py`

