# 19. 消息、聊天与消息分类

## iOS 来源

- `Features/Messages/MessagesHomeView.swift`
- `Features/Messages/ChatView.swift`
- `Features/Messages/MessagesViewModel.swift`
- `Features/Messages/MessageNotificationsViewModel.swift`

## Flutter 目标路径

```text
lib/features/messages/
```

## 页面职责

- 私信会话。
- 小队会话。
- 聊天详情。
- 消息分类/通知入口。
- 未读数刷新。

## 路由

```text
/app/messages
/conversations/:conversationId
/messages/alerts/:category
```

## API

- `GET /v1/chat/conversations?type=`
- `POST /v1/chat/conversations/:id/read`
- `POST /v1/chat/direct/start`
- `GET /v1/chat/conversations/:id/messages`
- `POST /v1/chat/conversations/:id/messages`
- `GET /v1/notifications/unread-count`
- `GET /v1/notifications`
- `POST /v1/notifications/read`

## UI 复刻

- 消息首页分私信/小队。
- 会话卡展示头像、标题、最后消息、未读 badge。
- ChatView 使用系统导航，输入框固定底部。
- 自己和对方气泡左右区分。
- 进入会话后 mark read。

## 状态模型

```text
MessagesHomeState
  selectedType
  conversations
  loading
  error

ChatState
  conversation
  messages
  draft
  sending
```

## 实现步骤

1. 建 MessagesRepository。
2. 会话按 type 加载。
3. Chat loader 按 conversationId。
4. 进入 chat 标记已读。
5. 发送消息后追加本地列表。
6. 返回 messages 时刷新未读数。

## 测试

- 私信/小队切换。
- 发送消息。
- mark read。
- 从用户主页 start direct conversation。

