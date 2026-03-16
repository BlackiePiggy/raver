#!/bin/bash

# Raver 项目初始化脚本
# 用于快速搭建开发环境

set -e

echo "🎵 Raver 项目初始化开始..."

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查必要的工具
check_requirements() {
    echo -e "${BLUE}检查必要工具...${NC}"

    if ! command -v node &> /dev/null; then
        echo -e "${YELLOW}Node.js 未安装，请先安装 Node.js 18+${NC}"
        exit 1
    fi

    if ! command -v pnpm &> /dev/null; then
        echo -e "${YELLOW}pnpm 未安装，正在安装...${NC}"
        npm install -g pnpm
    fi

    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker 未安装，请先安装 Docker${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ 工具检查完成${NC}"
}

# 创建项目结构
create_structure() {
    echo -e "${BLUE}创建项目结构...${NC}"

    mkdir -p {web,server,mobile,docs,scripts}
    mkdir -p web/{src,public}
    mkdir -p server/{src,prisma,tests}
    mkdir -p mobile/ios

    echo -e "${GREEN}✓ 项目结构创建完成${NC}"
}

# 初始化Web项目
init_web() {
    echo -e "${BLUE}初始化Web项目...${NC}"

    cd web

    # 创建Next.js项目
    pnpm create next-app@latest . --typescript --tailwind --app --src-dir --import-alias "@/*"

    # 安装依赖
    pnpm add @tanstack/react-query axios zustand
    pnpm add -D @types/node @types/react @types/react-dom

    echo -e "${GREEN}✓ Web项目初始化完成${NC}"
    cd ..
}

# 初始化后端项目
init_server() {
    echo -e "${BLUE}初始化后端项目...${NC}"

    cd server

    # 初始化package.json
    pnpm init

    # 安装依赖
    pnpm add express cors helmet morgan bcryptjs jsonwebtoken
    pnpm add @prisma/client
    pnpm add -D typescript @types/node @types/express @types/cors
    pnpm add -D @types/bcryptjs @types/jsonwebtoken
    pnpm add -D nodemon ts-node prisma

    # 初始化TypeScript
    npx tsc --init

    # 初始化Prisma
    npx prisma init

    echo -e "${GREEN}✓ 后端项目初始化完成${NC}"
    cd ..
}

# 创建Docker配置
create_docker() {
    echo -e "${BLUE}创建Docker配置...${NC}"

    # Docker Compose
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: raver-postgres
    environment:
      POSTGRES_USER: raver
      POSTGRES_PASSWORD: raver_dev_password
      POSTGRES_DB: raver_dev
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    container_name: raver-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
EOF

    echo -e "${GREEN}✓ Docker配置创建完成${NC}"
}

# 创建环境变量模板
create_env() {
    echo -e "${BLUE}创建环境变量模板...${NC}"

    # Web .env
    cat > web/.env.local << 'EOF'
NEXT_PUBLIC_API_URL=http://localhost:3001/api
NEXT_PUBLIC_APP_NAME=Raver
EOF

    # Server .env
    cat > server/.env << 'EOF'
# Database
DATABASE_URL="postgresql://raver:raver_dev_password@localhost:5432/raver_dev"

# Redis
REDIS_URL="redis://localhost:6379"

# JWT
JWT_SECRET="your-super-secret-jwt-key-change-in-production"
JWT_EXPIRES_IN="7d"

# Server
PORT=3001
NODE_ENV=development

# AWS S3 (可选)
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=
AWS_S3_BUCKET=

# Spotify API (可选)
SPOTIFY_CLIENT_ID=
SPOTIFY_CLIENT_SECRET=

# Apple Music API (可选)
APPLE_MUSIC_KEY_ID=
APPLE_MUSIC_TEAM_ID=
APPLE_MUSIC_PRIVATE_KEY=
EOF

    echo -e "${GREEN}✓ 环境变量模板创建完成${NC}"
}

# 创建README
create_readme() {
    echo -e "${BLUE}创建README...${NC}"

    cat > README.md << 'EOF'
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
EOF

    echo -e "${GREEN}✓ README创建完成${NC}"
}

# 创建Git配置
create_git() {
    echo -e "${BLUE}配置Git...${NC}"

    # .gitignore
    cat > .gitignore << 'EOF'
# Dependencies
node_modules/
.pnp
.pnp.js

# Testing
coverage/

# Next.js
.next/
out/
build/

# Production
dist/

# Misc
.DS_Store
*.pem

# Debug
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Local env files
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Vercel
.vercel

# TypeScript
*.tsbuildinfo

# IDE
.vscode/
.idea/
*.swp
*.swo

# Database
*.db
*.sqlite

# Logs
logs/
*.log
EOF

    git init
    git add .
    git commit -m "chore: initial commit"

    echo -e "${GREEN}✓ Git配置完成${NC}"
}

# 主函数
main() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════╗"
    echo "║   Raver - 电子音乐爱好者平台           ║"
    echo "║   项目初始化脚本                       ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"

    check_requirements
    create_structure
    create_docker
    create_env
    create_readme
    create_git

    # 询问是否初始化子项目
    read -p "是否初始化Web和Server项目? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        init_web
        init_server
    fi

    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════╗"
    echo "║   ✓ 项目初始化完成！                   ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${BLUE}下一步:${NC}"
    echo "1. 启动数据库: docker-compose up -d"
    echo "2. 配置环境变量: 编辑 web/.env.local 和 server/.env"
    echo "3. 运行数据库迁移: cd server && npx prisma migrate dev"
    echo "4. 启动开发服务器:"
    echo "   - 后端: cd server && pnpm dev"
    echo "   - 前端: cd web && pnpm dev"
    echo ""
    echo -e "${GREEN}Happy coding! 🎵${NC}"
}

# 运行主函数
main
