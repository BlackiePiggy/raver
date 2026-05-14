# Foundation 02 - Architecture And State

## 1. 总原则

Raver RN 采用 Hybrid 架构：

```text
Feature module
  screens/
  components/
  hooks/
  api/
  repositories/
  models/
  store/
```

公共能力进入：

```text
shared/
services/
store/
types/
```

## 2. Feature 模块规范

示例：

```text
features/feed/
  screens/
    FeedScreen.tsx
    PostDetailScreen.tsx
    ComposePostScreen.tsx
  components/
    PostCard.tsx
    PostActionBar.tsx
    CommentComposer.tsx
  hooks/
    useFeedViewModel.ts
    usePostDetailViewModel.ts
  api/
    feedApi.ts
    feedSchemas.ts
  repositories/
    feedRepository.ts
  models/
    post.ts
    comment.ts
  store/
    composeDraftStore.ts
  index.ts
```

规则：

- screen 只负责布局和用户事件绑定。
- hooks/viewModel 负责页面状态组合。
- repository 负责调用 API、DTO 转换和领域语义。
- api 只负责 HTTP endpoint。
- store 只放真正需要跨页面或持久化的客户端状态。
- shared 只放跨 feature 复用三次以上，或设计系统级组件。

## 3. 状态分层

### 服务端数据

使用 TanStack Query：

```text
events list/detail
dj list/detail
set list/detail
feed
comments
profile
notifications
search result
check-in projection
```

原因：

- 缓存、刷新、分页、重试、失效策略天然适配。
- 不污染全局 store。

### 全局客户端状态

使用 Zustand 或 Redux Toolkit：

```text
session
current user snapshot
theme
language
runtime config
unread count
global banners
feature flags
```

### 页面局部状态

使用 `useState` / `useReducer` / React Hook Form：

```text
筛选条件
弹窗开关
输入框
临时选中项
局部排序
```

### 持久化状态

使用 MMKV / Keychain：

```text
access token
refresh token
runtime mode
base URL
language
theme
draft post
recent search
```

## 4. Repository 规则

Repository 是 Swift iOS 到 RN 迁移最重要的边界。

示例：

```text
EventRepository
  listEvents()
  getEventDetail(eventId)
  favoriteEvent(eventId)
  getEventSchedule(eventId)
```

不要在组件里直接写：

```text
http.get('/api/events/' + id)
```

而是：

```text
const event = await eventRepository.getEventDetail(eventId)
```

## 5. ViewModel Hook 规则

复杂页面使用：

```text
useEventDetailViewModel(eventId)
usePostDetailViewModel(postId)
useProfileViewModel(userId)
useConversationViewModel(target)
```

ViewModel hook 应返回：

```text
data
status
error
refresh
actions
derived UI state
```

不要返回过多 JSX，也不要让 hook 直接依赖具体视觉组件。

## 6. API DTO 与 Domain Model

建议保留两层：

```text
DTO: server response shape
Domain Model: RN UI 使用的稳定 shape
```

好处：

- 后端字段变化时集中修复 mapper。
- iOS/RN 可以对齐领域概念。
- 测试 mapper 容易。

## 7. 模块边界

允许：

- `features/feed` 使用 `shared/ui`
- `features/feed` 使用 `services/api`
- `features/feed` 通过 navigation 跳转 `profile/user`

谨慎：

- feature 直接 import 另一个 feature 的内部 hooks。
- shared 反向依赖 feature。
- repository 里写 UI toast。

禁止：

- screen 直接拼 URL。
- API client 直接读组件状态。
- 把所有列表数据放进 global store。
- 每个页面都复制 loading/error/empty。

## 8. 验收

- 任意 feature 可以独立查到 screen、API、repository、model。
- 全局 store 文件数量少且职责清楚。
- Query key 有统一命名。
- DTO mapper 有测试。
- shared 组件无业务 API 依赖。

