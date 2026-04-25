#!/bin/bash

# Raver 一键启动脚本

echo "🎵 启动 Raver 开发环境..."
echo ""

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 检查Docker是否运行
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker未运行，请先启动Docker${NC}"
    exit 1
fi

# 1. 启动数据库
echo -e "${BLUE}1. 启动数据库...${NC}"
docker-compose up -d
sleep 5

# 检查数据库是否启动成功
if docker-compose ps | grep -q "Up"; then
    echo -e "${GREEN}✓ 数据库启动成功${NC}"
else
    echo -e "${RED}✗ 数据库启动失败${NC}"
    exit 1
fi
echo ""

# 2. 初始化Prisma
echo -e "${BLUE}2. 初始化数据库...${NC}"
cd server

if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}安装Server依赖...${NC}"
    pnpm install
fi

echo -e "${YELLOW}生成Prisma Client...${NC}"
pnpm prisma:generate

echo -e "${YELLOW}运行数据库迁移...${NC}"
pnpm prisma:migrate || echo -e "${YELLOW}首次迁移，请输入迁移名称（如: init）${NC}"

cd ..
echo -e "${GREEN}✓ 数据库初始化完成${NC}"
echo ""

# 3. 启动服务器
echo -e "${BLUE}3. 启动开发服务器...${NC}"
echo ""
echo -e "${GREEN}准备就绪！${NC}"
echo ""
echo -e "请在两个终端中分别运行:"
echo -e "  终端1: ${BLUE}cd server && pnpm dev${NC}"
echo -e "  终端2: ${BLUE}cd web && pnpm dev${NC}"
echo ""
echo -e "然后访问:"
echo -e "  前端: ${BLUE}http://localhost:3000${NC}"
echo -e "  后端: ${BLUE}http://localhost:3901${NC}"
echo ""
echo -e "${YELLOW}提示: 使用 Ctrl+C 停止服务器${NC}"
echo -e "${YELLOW}提示: 使用 docker-compose down 停止数据库${NC}"
