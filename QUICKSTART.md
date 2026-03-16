# Raver 快速启动指南

## 当前状态

✅ 项目结构已创建
✅ Web项目已配置 (Next.js + TypeScript + Tailwind CSS)
✅ Server项目已配置 (Node.js + Express + TypeScript + Prisma)
✅ Docker配置已创建
✅ 依赖正在安装中...

## 项目结构

```
raver/
├── web/                    # Next.js前端项目
│   ├── src/
│   │   └── app/
│   │       ├── page.tsx    # 首页
│   │       ├── layout.tsx  # 布局
│   │       └── globals.css # 全局样式
│   ├── public/             # 静态资源
│   ├── package.json
│   ├── tsconfig.json
│   ├── tailwind.config.js  # Tailwind配置(已包含设计系统颜色)
│   └── next.config.js
│
├── server/                 # Express后端项目
│   ├── src/
│   │   └── index.ts        # 入口文件
│   ├── prisma/
│   │   └── schema.prisma   # 数据库Schema
│   ├── package.json
│   ├── tsconfig.json
│   └── nodemon.json
│
├── docker-compose.yml      # PostgreSQL + Redis
├── .env                    # 环境变量
└── 设计文档/
    ├── DESIGN_SYSTEM.md
    ├── UI_SPECIFICATIONS.md
    ├── DATABASE_DESIGN.md
    ├── IOS_DESIGN.md
    └── ROADMAP.md
```

## 启动步骤

### 1. 启动数据库

```bash
# 启动PostgreSQL和Redis
docker-compose up -d

# 查看容器状态
docker-compose ps
```

### 2. 初始化数据库

```bash
cd server

# 生成Prisma Client
pnpm prisma:generate

# 运行数据库迁移
pnpm prisma:migrate

# (可选) 打开Prisma Studio查看数据库
pnpm prisma:studio
```

### 3. 启动后端服务器

```bash
cd server
pnpm dev

# 服务器将运行在 http://localhost:3001
# 访问 http://localhost:3001/health 检查健康状态
```

### 4. 启动前端开发服务器

```bash
# 新开一个终端
cd web
pnpm dev

# 前端将运行在 http://localhost:3000
```

### 5. 访问应用

打开浏览器访问: http://localhost:3000

你将看到一个暗黑科技风格的欢迎页面！

## 开发命令

### Web (前端)

```bash
cd web

pnpm dev          # 启动开发服务器
pnpm build        # 构建生产版本
pnpm start        # 启动生产服务器
pnpm lint         # 运行ESLint
```

### Server (后端)

```bash
cd server

pnpm dev                # 启动开发服务器(热重载)
pnpm build              # 编译TypeScript
pnpm start              # 启动生产服务器
pnpm prisma:generate    # 生成Prisma Client
pnpm prisma:migrate     # 运行数据库迁移
pnpm prisma:studio      # 打开Prisma Studio
```

### Docker

```bash
docker-compose up -d      # 启动所有服务
docker-compose down       # 停止所有服务
docker-compose logs -f    # 查看日志
docker-compose ps         # 查看容器状态
```

## 环境变量

### Web (.env.local)

```env
NEXT_PUBLIC_API_URL=http://localhost:3001/api
NEXT_PUBLIC_APP_NAME=Raver
```

### Server (.env)

```env
DATABASE_URL="postgresql://raver:raver_dev_password@localhost:5432/raver_dev"
REDIS_URL="redis://localhost:6379"
JWT_SECRET="your-super-secret-jwt-key-change-in-production"
JWT_EXPIRES_IN="7d"
PORT=3001
NODE_ENV=development
```

## 设计系统

项目已配置完整的设计系统，包括：

### 颜色
- 主色: `primary-purple` (#8B5CF6), `primary-blue` (#3B82F6)
- 强调色: `accent-green`, `accent-pink`, `accent-cyan`
- 背景: `bg-primary`, `bg-secondary`, `bg-tertiary`
- 文字: `text-primary`, `text-secondary`, `text-tertiary`

### 使用示例

```tsx
<div className="bg-bg-primary text-text-primary">
  <button className="bg-primary-purple hover:shadow-glow">
    点击我
  </button>
</div>
```

## 下一步开发

参考 `ROADMAP.md` 中的开发计划：

1. **Phase 1**: 完善基础功能
   - 用户认证系统
   - 基础UI组件库
   - 图片上传功能

2. **Phase 2**: 核心功能开发
   - 活动模块
   - DJ模块
   - 打卡系统

3. **Phase 3**: 社交功能
   - 用户系统
   - 粉丝牌系统
   - 讨论区

## 常见问题

### 1. 端口被占用

```bash
# 查找占用端口的进程
lsof -i :3000  # 前端
lsof -i :3001  # 后端

# 杀死进程
kill -9 <PID>
```

### 2. 数据库连接失败

```bash
# 检查Docker容器状态
docker-compose ps

# 重启数据库
docker-compose restart postgres
```

### 3. Prisma错误

```bash
# 重新生成Prisma Client
cd server
pnpm prisma:generate

# 重置数据库(警告: 会删除所有数据)
pnpm prisma migrate reset
```

## 技术文档

- [Next.js文档](https://nextjs.org/docs)
- [Tailwind CSS文档](https://tailwindcss.com/docs)
- [Prisma文档](https://www.prisma.io/docs)
- [Express文档](https://expressjs.com/)

## 需要帮助？

查看项目文档:
- `DESIGN_SYSTEM.md` - 设计系统规范
- `UI_SPECIFICATIONS.md` - UI设计详细说明
- `DATABASE_DESIGN.md` - 数据库设计
- `ROADMAP.md` - 开发路线图

祝开发顺利！🎵
