# Foundation 05 - Networking And BFF

## 1. 当前后端事实

Raver 当前后端是：

```text
server/
  Node.js
  Express
  TypeScript
  Prisma
  PostgreSQL
  Redis
```

主要 namespace：

```text
/api/auth
/api/events
/api/djs
/api/dj-sets
/api/music
/v1
/v1/search
/v1/im/tencent
/v1/notification-center
/v2/checkins
/api/admin/v1
```

RN 不应直接访问数据库，也不应复刻 Web API 拼接逻辑。RN 应复用 BFF / App API。

## 2. 网络层目录

```text
services/http/
  client.ts
  interceptors.ts
  errors.ts
  request.ts

services/api/
  authApi.ts
  eventsApi.ts
  djsApi.ts
  setsApi.ts
  feedApi.ts
  commentsApi.ts
  profileApi.ts
  notificationApi.ts
  tencentImApi.ts
  checkinsApi.ts
  searchApi.ts

services/api/schemas/
  auth.ts
  event.ts
  post.ts
  user.ts
```

## 3. HTTP Client 要求

必须支持：

- base URL from env / persisted config。
- Bearer token 自动注入。
- refresh token。
- 401 统一触发 session expired。
- 请求超时。
- 请求取消。
- debug 日志开关。
- BFF envelope 解包。
- zod schema 校验关键接口。
- multipart 上传。

## 4. Error Model

统一错误模型：

```ts
export type AppError = {
  code: string;
  message: string;
  status?: number;
  requestId?: string;
  retryable: boolean;
};
```

UI 不直接展示后端原始错误。Repository 负责转换为稳定错误。

## 5. Query Key

统一命名：

```text
['events', 'list', params]
['events', 'detail', eventId]
['djs', 'detail', djId]
['sets', 'detail', setId]
['feed', 'home', params]
['posts', 'detail', postId]
['comments', 'post', postId, params]
['profile', userId]
['notifications', 'inbox', params]
['search', query, tab]
```

mutation 成功后必须明确 invalidate 或 optimistic update。

## 6. 上传

媒体上传能力用于：

- 发帖图片/视频。
- 头像。
- 活动/DJ/Set 封面。
- 聊天媒体。

策略：

1. 先统一 `MediaUploadService`。
2. 本地生成 upload task。
3. 调 BFF 获取上传凭证或直接 multipart。
4. 上传完成后返回 asset URL / object key。
5. mutation 再提交业务实体。

## 7. Mock / Live

和 iOS 对齐：

```text
mock mode: 使用 fixture repository 或 mock API adapter
live mode: 使用真实 BFF
```

不要让页面知道当前是 mock 还是 live。

## 8. 验收

- token 注入和 401 logout 正常。
- 列表分页、刷新、错误重试正常。
- 后端关闭时 app 不崩溃。
- 上传失败能重试。
- mapper 测试覆盖关键 DTO。

