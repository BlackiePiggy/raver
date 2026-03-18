# 圈子模块 & 小队功能 - 架构设计

## 功能概览

### 圈子模块（Community）
社交互动的核心模块，包含：
- 动态发布（Feed/Post）
- 动态列表和详情
- 点赞、评论、分享
- 话题标签

### 小队功能（Squad）
核心社交功能，包含：
- 小队创建和管理
- 成员邀请和管理
- 小队聊天室（实时通讯）
- 活动记录管理
- 小队相册（按活动分类）

---

## 数据库设计

### 1. Post（动态）
```prisma
model Post {
  id          String   @id @default(uuid())
  userId      String   @map("user_id")
  content     String   @db.Text
  images      String[] @default([])
  type        String   @default("general") // general, event, set, squad
  visibility  String   @default("public")  // public, friends, squad
  squadId     String?  @map("squad_id")
  eventId     String?  @map("event_id")
  setId       String?  @map("set_id")
  likeCount   Int      @default(0) @map("like_count")
  commentCount Int     @default(0) @map("comment_count")
  createdAt   DateTime @default(now()) @map("created_at")
  updatedAt   DateTime @updatedAt @map("updated_at")

  user        User     @relation(...)
  squad       Squad?   @relation(...)
  event       Event?   @relation(...)
  set         DJSet?   @relation(...)
  likes       PostLike[]
  comments    PostComment[]
  tags        PostTag[]
}
```

### 2. Squad（小队）
```prisma
model Squad {
  id          String   @id @default(uuid())
  name        String
  description String?
  avatarUrl   String?  @map("avatar_url")
  bannerUrl   String?  @map("banner_url")
  leaderId    String   @map("leader_id")
  isPublic    Boolean  @default(false) @map("is_public")
  maxMembers  Int      @default(50) @map("max_members")
  createdAt   DateTime @default(now()) @map("created_at")
  updatedAt   DateTime @updatedAt @map("updated_at")

  leader      User     @relation("SquadLeader", ...)
  members     SquadMember[]
  invites     SquadInvite[]
  activities  SquadActivity[]
  albums      SquadAlbum[]
  messages    SquadMessage[]
  posts       Post[]
}
```

### 3. SquadMember（小队成员）
```prisma
model SquadMember {
  id          String   @id @default(uuid())
  squadId     String   @map("squad_id")
  userId      String   @map("user_id")
  role        String   @default("member") // leader, admin, member
  joinedAt    DateTime @default(now()) @map("joined_at")

  squad       Squad    @relation(...)
  user        User     @relation(...)

  @@unique([squadId, userId])
}
```

### 4. SquadInvite（小队邀请）
```prisma
model SquadInvite {
  id          String   @id @default(uuid())
  squadId     String   @map("squad_id")
  inviterId   String   @map("inviter_id")
  inviteeId   String   @map("invitee_id")
  status      String   @default("pending") // pending, accepted, rejected
  createdAt   DateTime @default(now()) @map("created_at")
  expiresAt   DateTime @map("expires_at")

  squad       Squad    @relation(...)
  inviter     User     @relation("SentInvites", ...)
  invitee     User     @relation("ReceivedInvites", ...)

  @@unique([squadId, inviteeId])
}
```

### 5. SquadActivity（小队活动记录）
```prisma
model SquadActivity {
  id          String   @id @default(uuid())
  squadId     String   @map("squad_id")
  eventId     String?  @map("event_id")
  title       String
  description String?
  location    String?
  date        DateTime
  participants String[] @default([]) // User IDs
  createdById String   @map("created_by_id")
  createdAt   DateTime @default(now()) @map("created_at")
  updatedAt   DateTime @updatedAt @map("updated_at")

  squad       Squad    @relation(...)
  event       Event?   @relation(...)
  createdBy   User     @relation(...)
  photos      SquadActivityPhoto[]
}
```

### 6. SquadAlbum（小队相册）
```prisma
model SquadAlbum {
  id          String   @id @default(uuid())
  squadId     String   @map("squad_id")
  activityId  String?  @map("activity_id")
  title       String
  description String?
  coverUrl    String?  @map("cover_url")
  createdById String   @map("created_by_id")
  createdAt   DateTime @default(now()) @map("created_at")
  updatedAt   DateTime @updatedAt @map("updated_at")

  squad       Squad    @relation(...)
  activity    SquadActivity? @relation(...)
  createdBy   User     @relation(...)
  photos      SquadAlbumPhoto[]
}
```

### 7. SquadAlbumPhoto（相册照片）
```prisma
model SquadAlbumPhoto {
  id          String   @id @default(uuid())
  albumId     String   @map("album_id")
  url         String
  caption     String?
  uploadedById String  @map("uploaded_by_id")
  uploadedAt  DateTime @default(now()) @map("uploaded_at")

  album       SquadAlbum @relation(...)
  uploadedBy  User     @relation(...)
}
```

### 8. SquadMessage（小队聊天消息）
```prisma
model SquadMessage {
  id          String   @id @default(uuid())
  squadId     String   @map("squad_id")
  userId      String   @map("user_id")
  content     String   @db.Text
  type        String   @default("text") // text, image, system
  imageUrl    String?  @map("image_url")
  createdAt   DateTime @default(now()) @map("created_at")

  squad       Squad    @relation(...)
  user        User     @relation(...)
}
```

### 9. PostLike（动态点赞）
```prisma
model PostLike {
  id          String   @id @default(uuid())
  postId      String   @map("post_id")
  userId      String   @map("user_id")
  createdAt   DateTime @default(now()) @map("created_at")

  post        Post     @relation(...)
  user        User     @relation(...)

  @@unique([postId, userId])
}
```

### 10. PostComment（动态评论）
```prisma
model PostComment {
  id          String   @id @default(uuid())
  postId      String   @map("post_id")
  userId      String   @map("user_id")
  content     String
  createdAt   DateTime @default(now()) @map("created_at")
  updatedAt   DateTime @updatedAt @map("updated_at")

  post        Post     @relation(...)
  user        User     @relation(...)
}
```

---

## 页面路由设计

### 圈子模块
```
/community                    # 圈子首页（动态列表）
/community/post/[id]          # 动态详情
/community/post/new           # 发布动态
```

### 小队功能
```
/squads                       # 小队列表
/squads/new                   # 创建小队
/squads/[id]                  # 小队主页
/squads/[id]/chat             # 小队聊天室
/squads/[id]/activities       # 活动记录
/squads/[id]/activities/new   # 创建活动记录
/squads/[id]/albums           # 小队相册
/squads/[id]/albums/[albumId] # 相册详情
/squads/[id]/members          # 成员管理
/squads/[id]/settings         # 小队设置（仅队长）
```

---

## API 端点设计

### 动态相关
```
GET    /api/posts                    # 获取动态列表
POST   /api/posts                    # 发布动态
GET    /api/posts/:id                # 获取动态详情
PUT    /api/posts/:id                # 编辑动态
DELETE /api/posts/:id                # 删除动态
POST   /api/posts/:id/like           # 点赞
DELETE /api/posts/:id/like           # 取消点赞
POST   /api/posts/:id/comments       # 评论
```

### 小队相关
```
GET    /api/squads                   # 获取小队列表
POST   /api/squads                   # 创建小队
GET    /api/squads/:id               # 获取小队详情
PUT    /api/squads/:id               # 更新小队信息
DELETE /api/squads/:id               # 解散小队

GET    /api/squads/:id/members       # 获取成员列表
POST   /api/squads/:id/members       # 添加成员
DELETE /api/squads/:id/members/:userId # 移除成员

GET    /api/squads/:id/invites       # 获取邀请列表
POST   /api/squads/:id/invites       # 发送邀请
PUT    /api/squads/:id/invites/:id   # 接受/拒绝邀请

GET    /api/squads/:id/activities    # 获取活动列表
POST   /api/squads/:id/activities    # 创建活动记录
GET    /api/squads/:id/activities/:activityId # 活动详情
PUT    /api/squads/:id/activities/:activityId # 更新活动
DELETE /api/squads/:id/activities/:activityId # 删除活动

GET    /api/squads/:id/albums        # 获取相册列表
POST   /api/squads/:id/albums        # 创建相册
GET    /api/squads/:id/albums/:albumId # 相册详情
POST   /api/squads/:id/albums/:albumId/photos # 上传照片
DELETE /api/squads/:id/albums/:albumId/photos/:photoId # 删除照片

GET    /api/squads/:id/messages      # 获取聊天消息
POST   /api/squads/:id/messages      # 发送消息
```

---

## 技术栈

### 实时通讯（小队聊天）
- **方案 1：轮询** - 简单但效率低
- **方案 2：WebSocket** - 实时性好，推荐使用
- **方案 3：Server-Sent Events (SSE)** - 单向推送

推荐使用 **Socket.IO** 实现 WebSocket：
```typescript
// server/src/socket.ts
import { Server } from 'socket.io';

export const initializeSocket = (httpServer: any) => {
  const io = new Server(httpServer, {
    cors: { origin: '*' }
  });

  io.on('connection', (socket) => {
    // 加入小队房间
    socket.on('join-squad', (squadId) => {
      socket.join(`squad-${squadId}`);
    });

    // 发送消息
    socket.on('send-message', (data) => {
      io.to(`squad-${data.squadId}`).emit('new-message', data);
    });
  });

  return io;
};
```

### 图片上传
- 使用 multer 处理文件上传
- 存储到本地 `/uploads` 目录
- 或集成云存储（阿里云 OSS、AWS S3）

---

## 权限设计

### 小队权限
- **队长（Leader）**：所有权限
- **管理员（Admin）**：管理成员、活动、相册
- **成员（Member）**：查看、发消息、上传照片

### 动态可见性
- **公开（Public）**：所有人可见
- **好友（Friends）**：仅好友可见
- **小队（Squad）**：仅小队成员可见

---

## UI 设计要点

### 导航栏
```
首页 | DJ | 活动 | 圈子 | 小队 | 我的
                  ↑     ↑
                新增    新增
```

### 圈子首页
```
┌─────────────────────────────────────┐
│  圈子                    [发布动态]  │
├─────────────────────────────────────┤
│  [全部] [关注] [小队]               │
├─────────────────────────────────────┤
│  👤 张三  •  2小时前                │
│  今天去了 Tomorrowland！太震撼了！  │
│  [图片1] [图片2] [图片3]            │
│  ❤️ 125  💬 23  🔗 分享            │
├─────────────────────────────────────┤
│  👤 李四  •  5小时前                │
│  分享一个超棒的 set！                │
│  [DJ Set 卡片]                      │
│  ❤️ 89  💬 15  🔗 分享             │
└─────────────────────────────────────┘
```

### 小队主页
```
┌─────────────────────────────────────┐
│  [封面图片]                          │
│  🎵 EDM Lovers                      │
│  👥 25/50 成员                      │
│  [加入小队] [聊天] [活动] [相册]    │
├─────────────────────────────────────┤
│  📝 简介                            │
│  我们是一群热爱电音的朋友...        │
├─────────────────────────────────────┤
│  🎪 最近活动                        │
│  • Tomorrowland 2026 (15人参加)    │
│  • Ultra Miami 2026 (8人参加)      │
├─────────────────────────────────────┤
│  📸 最新照片                        │
│  [照片1] [照片2] [照片3]            │
└─────────────────────────────────────┘
```

### 小队聊天室
```
┌─────────────────────────────────────┐
│  🎵 EDM Lovers                      │
│  25 成员在线                         │
├─────────────────────────────────────┤
│  👤 张三  10:30                     │
│  大家周末有空吗？                    │
│                                     │
│                     10:32  李四 👤  │
│                     有！什么活动？   │
│                                     │
│  👤 王五  10:35                     │
│  我也有空！                          │
├─────────────────────────────────────┤
│  [输入消息...]              [发送]  │
└─────────────────────────────────────┘
```

---

## 实现优先级

### Phase 1：基础功能（必须）
1. ✅ 数据库 schema
2. ✅ 小队创建和管理
3. ✅ 成员邀请系统
4. ✅ 动态发布和列表
5. ✅ 导航栏集成

### Phase 2：核心功能（重要）
6. ⏳ 小队聊天室（WebSocket）
7. ⏳ 活动记录管理
8. ⏳ 小队相册
9. ⏳ 动态点赞和评论

### Phase 3：增强功能（可选）
10. ⏳ 实时通知
11. ⏳ 图片上传优化
12. ⏳ 搜索功能
13. ⏳ 数据统计

---

## 下一步行动

我现在可以开始实现：

### 选项 A：先实现圈子模块
- 动态发布和列表
- 点赞和评论
- 导航栏集成

### 选项 B：先实现小队基础功能
- 小队创建和管理
- 成员邀请系统
- 小队主页

### 选项 C：同时推进
- 先做数据库 schema
- 然后并行开发两个模块

你想从哪个开始？
