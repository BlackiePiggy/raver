# Raver

Raver 是一个围绕电子音乐活动、DJ、Set、社区、小队与线下协同构建的 App-first 垂直社交平台。

当前项目不只是活动列表或音乐内容站，而是同时包含活动平台、DJ / Set 内容系统、社区 Feed、小队社交、IM、Check-in、通知中心、分享短链、虚拟资产和运营后台的复合系统。

## 当前主线

- **主客户端**：iOS Native App，位于 `mobile/ios/RaverMVP/`
- **后端**：Node.js + Express + TypeScript + Prisma，位于 `server/`
- **Cloudflare 部署层**：Worker + Container 入口，位于 `cloudflare/backend/`
- **数据库**：PostgreSQL，开发环境通过 Docker Compose 启动
- **缓存**：Redis
- **Web**：Next.js，用于 Admin Console、CMS、预报名、公开 fallback 和历史 Web 页面
- **实时通讯**：Tencent IM 是当前 IM 主线，OpenIM 相关内容作为历史 / 迁移 / 兼容参考
- **通知**：Notification Center + APNs 是当前通知主线
- **打卡系统**：Check-in v2 projection read model 是当前打卡主线

## 技术栈

### iOS

- SwiftUI + UIKit
- Coordinator / MVVM 演进中
- Tencent IM SDK integration
- Widget Extension
- Notification Service Extension

### Backend

- Node.js
- Express
- TypeScript
- Prisma ORM
- PostgreSQL
- Redis
- Ali OSS
- APNs
- Tencent IM REST / usersig integration

### Web / Admin

- Next.js
- React
- TypeScript
- Tailwind CSS

## 快速开始

### 1. 安装依赖

```bash
cd server && pnpm install
cd ../web && pnpm install
```

### 2. 启动数据库和 Redis

```bash
docker-compose up -d
```

### 3. 初始化数据库

```bash
cd server
npx prisma migrate dev
npx prisma db seed
```

### 4. 启动开发服务

推荐一条命令启动 Web、主后端和 Festival Viewer WebTool：

```bash
./start-all.sh
```

启动后访问：

- Web: `http://127.0.0.1:3000`
- 后台工作台: `http://127.0.0.1:3000/admin`
- Content CMS: `http://127.0.0.1:3000/admin/content-cms`
- Festival Viewer: `http://127.0.0.1:3000/admin/festival-viewer.html`

如需分别启动：

```bash
cd server && pnpm dev
```

```bash
cd web && pnpm dev
```

默认服务：

- Backend: `http://localhost:3901`
- Web: `http://localhost:3000`
- Festival Viewer WebTool: `http://127.0.0.1:8000`

### 5. iOS

使用 Xcode 打开：

```text
mobile/ios/RaverMVP/RaverMVP.xcworkspace
```

## 项目结构

```text
raver/
  server/        # Express + TypeScript + Prisma 后端
  web/           # Next.js Web / Admin / Public fallback
  mobile/        # iOS App 和移动端相关工程
  docs/          # 当前主线文档、ADR、运行手册、改造 tracker
  scripts/       # 项目级辅助脚本
  thirdparty/    # 第三方源码或本地依赖
```

## 关键文档

建议从这里开始：

- [Docs Index](./docs/README.md)
- [Platform Architecture](./docs/RAVER_PLATFORM_ARCHITECTURE.md)
- [Commercial Architecture Restructure Plan](./docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_PLAN.md)
- [Restructure Tracker](./docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md)
- [Cloudflare Backend Deployment](./docs/CLOUDFLARE_BACKEND_DEPLOYMENT.md)

关键 ADR：

- [ADR-0001 App-first iOS Native](./docs/adr/0001-app-first-ios-native.md)
- [ADR-0002 Tencent IM As Current IM Provider](./docs/adr/0002-tencent-im-as-current-im-provider.md)
- [ADR-0003 Check-in v2 Projection Read Model](./docs/adr/0003-checkin-v2-projection-read-model.md)
- [ADR-0004 Notification Center As Current Notification System](./docs/adr/0004-notification-center-current-system.md)
- [ADR-0005 Modular Monolith Before Microservices](./docs/adr/0005-modular-monolith-before-microservices.md)
- [ADR-0006 Admin Console Over Public Web First](./docs/adr/0006-admin-console-over-public-web-first.md)

## 架构改造纪律

当前项目正在进行商用级架构收束。改造期间遵循：

- 先收束主线，再移动代码。
- 新需求先进入 deferred backlog，避免路线漂移。
- 数据库结构变更、迁移、回填、reproject apply、snapshot rebuild 前必须先备份并验证备份可读。
- 旧路线先标记 legacy，再迁移，再删除。
- 每次改造都更新 [Restructure Tracker](./docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md)。

## 常用命令

```bash
# 后端开发
cd server && pnpm dev

# 后端构建
cd server && pnpm build

# Prisma
cd server && pnpm prisma:generate
cd server && pnpm prisma:migrate

# Check-in projection health
cd server && pnpm checkins:projection:freshness

# Web 开发
cd web && pnpm dev

# Web 构建
cd web && pnpm build
```

## License

MIT
