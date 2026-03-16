# 🔧 API 错误修复完成

## 问题原因
1. 后端服务器未运行
2. 前端使用 `process.env` 在浏览器端不可用
3. API URL 配置不统一

## 已修复
✅ 创建统一的 API 配置文件 (`lib/config.ts`)
✅ 更新所有 API 调用使用新配置
✅ 修复 `/sets` 页面的 fetch 调用
✅ 修复 `DJSetUploader` 组件
✅ 修复 `api.ts` 中的所有 API 类
✅ 创建启动脚本确保服务器运行

## 启动服务

### 方式1: 使用启动脚本（推荐）
```bash
./start-all.sh
```

### 方式2: 手动启动
```bash
# 终端1 - 后端
cd server
pnpm dev

# 终端2 - 前端
cd web
pnpm dev
```

## 验证修复

### 1. 检查后端
```bash
curl http://localhost:3001/health
# 应该返回: {"status":"ok","timestamp":"..."}
```

### 2. 检查DJ Sets API
```bash
curl http://localhost:3001/api/dj-sets | jq '.[0].title'
# 应该返回DJ Set标题
```

### 3. 访问前端
打开浏览器访问：
- http://localhost:3000 （主页）
- http://localhost:3000/sets （DJ Sets列表）
- http://localhost:3000/dj-sets/9aa16d0a-0106-4e56-aedd-a49527d5dbbb （Said the Sky）

## 修改的文件

1. **新增文件**:
   - `web/src/lib/config.ts` - 统一API配置

2. **修改文件**:
   - `web/src/app/sets/page.tsx` - 使用新配置
   - `web/src/components/DJSetUploader.tsx` - 使用新配置
   - `web/src/lib/api.ts` - 使用新配置

3. **工具脚本**:
   - `start-all.sh` - 一键启动所有服务

## 配置说明

### API 配置 (`lib/config.ts`)
```typescript
export const API_BASE_URL =
  typeof window !== 'undefined'
    ? 'http://localhost:3001/api' // 浏览器端
    : process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api'; // 服务端

export const getApiUrl = (path: string) => {
  const baseUrl = API_BASE_URL;
  return `${baseUrl}${path.startsWith('/') ? path : `/${path}`}`;
};
```

### 使用方法
```typescript
import { getApiUrl } from '@/lib/config';

// 替代
const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/dj-sets`);

// 使用
const response = await fetch(getApiUrl('/dj-sets'));
```

## 常见问题

### Q: 页面显示 "Failed to fetch"
**A**: 确保后端服务器正在运行
```bash
# 检查
curl http://localhost:3001/health

# 如果失败，启动服务器
cd server && pnpm dev
```

### Q: 端口被占用
**A**: 杀死占用端口的进程
```bash
# 查找进程
lsof -ti:3001

# 杀死进程
kill -9 $(lsof -ti:3001)
```

### Q: 前端无法连接后端
**A**: 检查 CORS 配置和端口
```bash
# 确认后端运行在 3001
curl http://localhost:3001/api/dj-sets

# 确认前端运行在 3000
curl http://localhost:3000
```

## 测试清单

- [ ] 后端健康检查通过
- [ ] 主页加载正常
- [ ] DJ Sets 列表页加载
- [ ] 排序功能正常
- [ ] 筛选功能正常
- [ ] Said the Sky Set 播放正常
- [ ] 点击歌曲跳转正常

## 下一步

1. 运行 `./start-all.sh` 启动所有服务
2. 访问 http://localhost:3000
3. 点击导航栏 "DJ Sets"
4. 测试所有功能

---

**现在应该可以正常使用了！** 🎉