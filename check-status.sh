#!/bin/bash

# Raver 项目状态检查脚本

echo "🎵 Raver 项目状态检查"
echo "================================"
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查函数
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
    fi
}

# 1. 检查项目文件
echo -e "${BLUE}📁 项目文件检查${NC}"
[ -f "package.json" ] && echo -e "${GREEN}✓${NC} 根目录配置" || echo -e "${YELLOW}○${NC} 根目录配置（可选）"
[ -f "docker-compose.yml" ] && check_status "Docker配置"
[ -f "README.md" ] && check_status "README文档"
[ -f "QUICKSTART.md" ] && check_status "快速启动指南"
echo ""

# 2. 检查Web项目
echo -e "${BLUE}🌐 Web项目检查${NC}"
[ -d "web" ] && check_status "Web目录存在"
[ -f "web/package.json" ] && check_status "Web package.json"
[ -f "web/tsconfig.json" ] && check_status "Web TypeScript配置"
[ -f "web/tailwind.config.js" ] && check_status "Web Tailwind配置"
[ -f "web/src/app/page.tsx" ] && check_status "Web 首页组件"
[ -d "web/node_modules" ] && echo -e "${GREEN}✓${NC} Web依赖已安装" || echo -e "${YELLOW}○${NC} Web依赖安装中..."
echo ""

# 3. 检查Server项目
echo -e "${BLUE}⚙️  Server项目检查${NC}"
[ -d "server" ] && check_status "Server目录存在"
[ -f "server/package.json" ] && check_status "Server package.json"
[ -f "server/tsconfig.json" ] && check_status "Server TypeScript配置"
[ -f "server/src/index.ts" ] && check_status "Server 入口文件"
[ -f "server/prisma/schema.prisma" ] && check_status "Prisma Schema"
[ -d "server/node_modules" ] && echo -e "${GREEN}✓${NC} Server依赖已安装" || echo -e "${YELLOW}○${NC} Server依赖安装中..."
echo ""

# 4. 检查Docker
echo -e "${BLUE}🐳 Docker检查${NC}"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker已安装"

    if docker-compose ps 2>/dev/null | grep -q "Up"; then
        echo -e "${GREEN}✓${NC} Docker容器运行中"
    else
        echo -e "${YELLOW}○${NC} Docker容器未启动"
        echo -e "   运行: ${BLUE}docker-compose up -d${NC}"
    fi
else
    echo -e "${RED}✗${NC} Docker未安装"
fi
echo ""

# 5. 检查端口
echo -e "${BLUE}🔌 端口检查${NC}"
if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${YELLOW}!${NC} 端口3000已被占用"
else
    echo -e "${GREEN}✓${NC} 端口3000可用"
fi

if lsof -Pi :3901 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${YELLOW}!${NC} 端口3901已被占用"
else
    echo -e "${GREEN}✓${NC} 端口3901可用"
fi

if lsof -Pi :5432 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} PostgreSQL端口5432运行中"
else
    echo -e "${YELLOW}○${NC} PostgreSQL端口5432未使用"
fi
echo ""

# 6. 设计文档
echo -e "${BLUE}📚 设计文档${NC}"
[ -f "DESIGN_SYSTEM.md" ] && check_status "设计系统"
[ -f "UI_SPECIFICATIONS.md" ] && check_status "UI规范"
[ -f "DATABASE_DESIGN.md" ] && check_status "数据库设计"
[ -f "IOS_DESIGN.md" ] && check_status "iOS设计"
[ -f "ROADMAP.md" ] && check_status "开发路线图"
echo ""

# 7. 下一步建议
echo -e "${BLUE}🚀 下一步操作${NC}"
echo ""

if [ ! -d "web/node_modules" ] || [ ! -d "server/node_modules" ]; then
    echo -e "${YELLOW}1.${NC} 等待依赖安装完成"
    echo -e "   ${BLUE}cd web && pnpm install${NC}"
    echo -e "   ${BLUE}cd server && pnpm install${NC}"
    echo ""
fi

if ! docker-compose ps 2>/dev/null | grep -q "Up"; then
    echo -e "${YELLOW}2.${NC} 启动数据库"
    echo -e "   ${BLUE}docker-compose up -d${NC}"
    echo ""
fi

echo -e "${YELLOW}3.${NC} 初始化数据库"
echo -e "   ${BLUE}cd server${NC}"
echo -e "   ${BLUE}pnpm prisma:generate${NC}"
echo -e "   ${BLUE}pnpm prisma:migrate${NC}"
echo ""

echo -e "${YELLOW}4.${NC} 启动开发服务器"
echo -e "   终端1: ${BLUE}cd server && pnpm dev${NC}"
echo -e "   终端2: ${BLUE}cd web && pnpm dev${NC}"
echo ""

echo -e "${YELLOW}5.${NC} 访问应用"
echo -e "   前端: ${BLUE}http://localhost:3000${NC}"
echo -e "   后端: ${BLUE}http://localhost:3901${NC}"
echo ""

echo "================================"
echo -e "${GREEN}项目初始化完成！查看 QUICKSTART.md 了解详情${NC}"
