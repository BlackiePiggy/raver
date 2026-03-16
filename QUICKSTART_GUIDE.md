# 🚀 Raver 项目启动指南

## 快速启动（3步）

### 1️⃣ 启动数据库
```bash
docker-compose up -d
```

### 2️⃣ 启动后端（新终端）
```bash
cd server
pnpm dev
```
✅ 后端运行在 http://localhost:3001

### 3️⃣ 启动前端（新终端）
```bash
cd web
pnpm dev
```
✅ 前端运行在 http://localhost:3002

---

## 🎯 访问应用

打开浏览器访问: **http://localhost:3002**

### 测试账号
- 邮箱: `test@example.com`
- 密码: `password123`

---

## 📦 创建测试数据（可选）

```bash
./test-auth.sh      # 创建测试用户
./seed-events.sh    # 创建6个测试活动
./seed-djs.sh       # 创建8个测试DJ
```

---

## 🧪 运行测试

```bash
./test-all.sh       # 完整测试（推荐）
./test-social.sh    # 测试打卡和关注功能
```

---

## 📱 功能演示

### 1. 浏览活动
- 访问 http://localhost:3002/events
- 查看6个测试活动
- 搜索和筛选活动

### 2. 浏览DJ
- 访问 http://localhost:3002/djs
- 查看8个测试DJ
- 按热度/名称/最新排序

### 3. 关注DJ
- 进入任意DJ详情页
- 点击"关注"按钮
- 查看粉丝数变化

### 4. 打卡
- 进入任意DJ详情页
- 点击"打卡"按钮
- 访问 http://localhost:3002/checkins 查看记录

---

## 🛠 常用命令

### 数据库管理
```bash
cd server
pnpm prisma:studio      # 打开数据库管理界面
pnpm prisma migrate reset  # 重置数据库
```

### 查看日志
```bash
docker-compose logs -f postgres  # 查看数据库日志
docker-compose logs -f redis     # 查看Redis日志
```

### 停止服务
```bash
docker-compose down     # 停止数据库
# Ctrl+C 停止后端和前端
```

---

## ❓ 遇到问题？

### 端口被占用
```bash
lsof -i :3001  # 查找占用3001端口的进程
lsof -i :3002  # 查找占用3002端口的进程
kill -9 <PID>  # 杀死进程
```

### 数据库连接失败
```bash
docker-compose ps      # 检查容器状态
docker-compose restart postgres  # 重启数据库
```

### 依赖安装失败
```bash
cd server && pnpm install
cd web && pnpm install
```

---

## 📚 更多文档

- `PHASE3_FINAL_REPORT.md` - 完整开发报告
- `ACCESS_GUIDE.md` - 详细访问指南
- `README.md` - 项目说明

---

**祝你使用愉快！** 🎵
