# Raver - 电子音乐爱好者平台

面向电子音乐爱好者的综合社交平台，提供活动信息、打卡集邮、音乐分类、歌单分享等功能。

## 技术栈

- **前端**: React 18 + Next.js 14 + TypeScript + Tailwind CSS
- **后端**: Node.js + Express + TypeScript
- **数据库**: PostgreSQL + Prisma ORM
- **缓存**: Redis
- **移动端**: React Native (iOS)

## 快速开始

### 1. 安装依赖

```bash
# Web
cd web && pnpm install

# Server
cd server && pnpm install
```

### 2. 启动数据库

```bash
docker-compose up -d
```

### 3. 数据库迁移

```bash
cd server
npx prisma migrate dev
npx prisma db seed
```

### 4. 启动开发服务器

```bash
# 后端 (终端1)
cd server && pnpm dev

# 前端 (终端2)
cd web && pnpm dev
```

访问 http://localhost:3000

## 项目结构

```
raver/
├── web/                # Next.js前端
├── server/             # Express后端
├── mobile/             # React Native移动端
├── docs/               # 文档
└── scripts/            # 脚本
```

## 文档

- [设计系统](./DESIGN_SYSTEM.md)
- [UI规范](./UI_SPECIFICATIONS.md)
- [数据库设计](./DATABASE_DESIGN.md)
- [iOS设计](./IOS_DESIGN.md)
- [开发路线图](./ROADMAP.md)

## 开发规范

- 使用TypeScript
- 遵循ESLint规则
- 提交前运行Prettier
- 编写单元测试
- 提交信息遵循Conventional Commits

## License

MIT
