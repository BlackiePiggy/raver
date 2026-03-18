# 评论系统实现方案

## 已完成：数据库层 ✅

### Comment 模型
```prisma
model Comment {
  id          String   @id @default(uuid())
  setId       String   @map("set_id")        // 关联的 DJ Set
  userId      String   @map("user_id")       // 评论者
  parentId    String?  @map("parent_id")     // 父评论（支持回复）
  content     String                          // 评论内容
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  set         DJSet    @relation(...)
  user        User     @relation(...)
  parent      Comment? @relation(...)        // 父评论
  replies     Comment[] @relation(...)       // 子评论（回复）
}
```

### 特性
- ✅ 支持嵌套回复（parent-child 关系）
- ✅ 级联删除（删除 DJ Set 时自动删除评论）
- ✅ 索引优化（setId, userId, parentId, createdAt）

---

## 待实现：后端 API

### 路由设计
```typescript
// /server/src/routes/comment.routes.ts

GET    /api/dj-sets/:setId/comments          // 获取评论列表
POST   /api/dj-sets/:setId/comments          // 发表评论
PUT    /api/comments/:id                     // 编辑评论
DELETE /api/comments/:id                     // 删除评论
POST   /api/comments/:id/reply               // 回复评论
```

### 服务层
```typescript
// /server/src/services/comment.service.ts

class CommentService {
  // 获取 DJ Set 的所有评论（包含用户信息和回复）
  async getComments(setId: string)

  // 创建评论
  async createComment(setId: string, userId: string, content: string, parentId?: string)

  // 更新评论
  async updateComment(commentId: string, userId: string, content: string)

  // 删除评论
  async deleteComment(commentId: string, userId: string, role?: string)

  // 获取评论数量
  async getCommentCount(setId: string)
}
```

---

## 待实现：前端组件

### 组件结构
```
/web/src/components/
├── CommentSection.tsx          // 评论区容器
├── CommentList.tsx             // 评论列表
├── CommentItem.tsx             // 单条评论
├── CommentForm.tsx             // 评论输入框
└── CommentReplyForm.tsx        // 回复输入框
```

### CommentSection 组件
```typescript
interface CommentSectionProps {
  setId: string;
  setTitle: string;
}

// 功能：
// - 显示评论总数
// - 评论列表（分页）
// - 发表评论表单
// - 登录提示（未登录用户）
```

### CommentItem 组件
```typescript
interface CommentItemProps {
  comment: Comment;
  onReply: (commentId: string) => void;
  onDelete: (commentId: string) => void;
  onEdit: (commentId: string, content: string) => void;
}

// 功能：
// - 显示评论内容
// - 显示用户头像和昵称
// - 显示时间
// - 回复按钮
// - 编辑/删除按钮（仅自己的评论）
// - 嵌套显示回复
```

---

## UI 设计

### 评论区布局
```
┌─────────────────────────────────────────────┐
│  💬 评论 (125)                              │
├─────────────────────────────────────────────┤
│  [登录后可以发表评论]                       │  ← 未登录
│                                             │
│  或                                         │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │ 👤 [输入评论...]                    │   │  ← 已登录
│  │                          [���表评论]  │   │
│  └─────────────────────────────────────┘   │
├─────────────────────────────────────────────┤
│  👤 张三  •  2小时前                        │
│  这个 set 太棒了！                          │
│  [回复] [编辑] [删除]                       │
│                                             │
│    └─ 👤 李四  •  1小时前                   │
│       同意！特别是第15分钟那段               │
│       [回复] [删除]                         │
├───────────────────────────────────��─────────┤
│  👤 王五  •  3小时前                        │
│  求 tracklist！                             │
│  [回复]                                     │
├─────────────────────────────────────────────┤
│  [加载更多评论]                             │
└─────────────────────────────────────────────┘
```

### 样式特点
- 使用网站主题色
- 头像圆形显示
- 时间相对显示（刚刚、5分钟前、2小时前）
- 回复缩进显示
- hover 效果
- 编辑/删除按钮仅对自己的评论可见

---

## 权限控制

### 发表评论
- ✅ 必须登录
- ✅ 内容不能为空
- ✅ 内容长度限制（1-1000字符）

### 编辑评论
- ✅ 只能编辑自己的评论
- ✅ 5分钟内可编辑

### 删除评论
- ✅ 只能删除自己的评论
- ✅ 管理员可以删除任何评论
- ✅ 删除父评论时，子评论也会被删除

---

## 实现步骤

### 第1步：后端 API ⏳
1. 创建 comment.service.ts
2. 创建 comment.routes.ts
3. 在 index.ts 中注册路由
4. 测试 API

### 第2步：前端组件 ⏳
1. 创建 CommentSection 组件
2. 创建 CommentItem 组件
3. 创建 CommentForm 组件
4. 集成到 DJSetPlayer 页面

### 第3步：优化 ⏳
1. 添加分页
2. 添加实时更新
3. 添加点赞功能（可选）
4. 添加举报功能（可选）

---

## 下一步行动

我现在可以继续实现：
1. **后端 API** - 创建完整的评论服务和路由
2. **前端组件** - 创建评论区 UI 组件
3. **集成测试** - 确保功能正常工作

你想让我继续哪一部分？还是你有其他的优先级调整？
