# 🎵 Raver 项目访问指南

## 快速开始

### 1. 确认服务运行状态

运行测试脚本检查所有服务：
```bash
./test-all.sh
```

应该看到：
```
✅ 所有测试通过！
通过: 15
失败: 0
```

### 2. 访问应用

#### 前端应用
打开浏览器访问: **http://localhost:3002**

#### 后端 API
API 地址: **http://localhost:3001**

---

## 页面导航

### 首页 (/)
- 显示欢迎信息
- 右上角显示登录状态
- 三个功能卡片：
  - 🎪 活动资讯 → 点击进入活动列表
  - ✅ 打卡集邮 → 即将推出
  - 🎧 DJ库 → 点击进入 DJ 列表

### 登录页面 (/login)
- 使用测试账号登录：
  - 邮箱: `test@example.com`
  - 密码: `password123`

### 注册页面 (/register)
- 创建新账号
- 需要填写：用户名、邮箱、密码

### 活动列表 (/events)
- 查看所有电音活动
- 搜索活动
- 点击卡片查看详情
- 当前有 6 个测试活动

### 活动详情 (/events/[id])
- 查看活动完整信息
- 活动时间、地点
- 购票链接（如果有）
- 官方网站（如果有）

### DJ 列表 (/djs)
- 查看所有 DJ
- 搜索 DJ
- 按热度/名称/最新排序
- 点击卡片查看详情
- 当前有 8 个测试 DJ

### DJ 详情 (/djs/[id])
- 查看 DJ 完整信息
- DJ 简介
- 粉丝数量
- 音乐平台链接（Spotify、SoundCloud 等）
- 社交媒体链接

---

## 功能演示

### 1. 用户认证流程

1. 访问首页 http://localhost:3002
2. 点击右上角 "Login" 按钮
3. 输入测试账号：
   - 邮箱: test@example.com
   - 密码: password123
4. 登录成功后，右上角显示 "Welcome, testuser!"
5. 可以点击 "Logout" 退出登录

### 2. 浏览活动

1. 在首页点击 "活动资讯" 卡片
2. 或直接访问 http://localhost:3002/events
3. 查看活动列表，包括：
   - Ultra Music Festival 2026
   - Tomorrowland 2026
   - EDC Las Vegas 2026
   - Creamfields 2026
   - Storm Festival Shanghai 2026
   - Road to Ultra Beijing 2026
4. 点击任意活动卡片查看详情
5. 使用搜索框搜索活动

### 3. 浏览 DJ

1. 在首页点击 "DJ库" 卡片
2. 或直接访问 http://localhost:3002/djs
3. 查看 DJ 列表，包括：
   - Martin Garrix
   - David Guetta
   - Armin van Buuren
   - Tiësto
   - Marshmello
   - Calvin Harris
   - Alan Walker
   - Kygo
4. 点击任意 DJ 卡片查看详情
5. 使用排序按钮切换排序方式
6. 使用搜索框搜索 DJ

---

## API 测试

### 使用 curl 测试

#### 1. 健康检查
```bash
curl http://localhost:3001/health
```

#### 2. 获取活动列表
```bash
curl http://localhost:3001/api/events
```

#### 3. 获取 DJ 列表
```bash
curl http://localhost:3001/api/djs
```

#### 4. 用户登录
```bash
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

---

## 常见问题

### Q: 页面显示空白？
A: 检查前端服务是否运行：
```bash
curl http://localhost:3002
```

### Q: API 返回错误？
A: 检查后端服务是否运行：
```bash
curl http://localhost:3001/health
```

### Q: 数据库连接失败？
A: 检查 Docker 容器是否运行：
```bash
docker-compose ps
```

### Q: 没有测试数据？
A: 运行数据脚本：
```bash
./test-auth.sh      # 创建测试用户
./seed-events.sh    # 创建测试活动
./seed-djs.sh       # 创建测试 DJ
```

---

## 设计特色

### 暗黑科技风格
- 深色背景 (#0F0F0F)
- 紫蓝渐变主色
- 发光效果
- 流畅动画

### 响应式设计
- 支持桌面端
- 支持平板
- 支持移动端

### 交互反馈
- 悬停效果
- 点击反馈
- 加载状态
- 错误提示

---

## 下一步

Phase 3 将开发：
- 打卡系统
- 用户个人主页
- 粉丝牌系统
- 关注功能
- 讨论区

---

**享受你的 Raver 之旅！** 🎵
