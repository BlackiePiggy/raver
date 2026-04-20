# 05. 网络层与 BFF 契约

## 目标

复用现有 `/v1` BFF。Flutter 侧建立强类型 API client、DTO、repository，不在页面中散落请求逻辑。

## iOS 对照

- `Core/LiveSocialService.swift`
- `Core/LiveWebFeatureService.swift`
- `Core/SocialService.swift`
- `Core/WebFeatureService.swift`
- `Core/Models.swift`
- `Core/WebFeatureModels.swift`

## API Client 拆分

首期：

```text
AuthApiClient
SocialApiClient
DiscoverApiClient
UploadApiClient
```

后续如果文件过大，再细拆：

```text
EventsApiClient
DjsApiClient
DjSetsApiClient
LearnApiClient
MessagesApiClient
ProfileApiClient
```

## Dio 配置

必须具备：

- base URL 来自 `AppConfig`
- connect/read/write timeout
- Bearer token interceptor
- 401 interceptor 触发 session expired
- debug log interceptor
- multipart helper
- cancel token
- retry 只用于幂等 GET

## BFF Envelope

统一定义：

```text
BffEnvelope<T>
BffItems<T>
BffPagination
ApiError
```

页面 ViewModel 不直接处理 envelope，只拿 domain model。

## DTO 与 Domain Model

规则：

- DTO 匹配 BFF JSON。
- Domain model 适合 UI 和业务。
- DTO -> Domain conversion 在 repository。
- 日期统一转换为 `DateTime`，明确 UTC/local。
- 可空字段必须显式处理 fallback。

## 首批接口

Auth：

- `POST /v1/auth/login`
- `POST /v1/auth/register`
- `GET /v1/profile/me`

Discover：

- `GET /v1/events`
- `GET /v1/events/recommendations`
- `GET /v1/events/:id`
- `GET /v1/djs`
- `GET /v1/djs/:id`
- `GET /v1/dj-sets`
- `GET /v1/dj-sets/:id`
- `GET /v1/learn/genres`
- `GET /v1/learn/labels`
- `GET /v1/learn/festivals`

Social：

- `GET /v1/feed`
- `GET /v1/feed/posts/:id`
- `GET /v1/chat/conversations`
- `GET /v1/profile/me`

## 错误处理

错误类型：

- network unavailable
- timeout
- unauthorized
- forbidden
- validation
- server
- decode mismatch
- unknown

页面呈现：

- 首屏失败：full error state + retry
- 分页失败：底部 retry row
- 提交失败：toast/snackbar + 保留表单
- 401：全局退登

## 复刻步骤

1. 先从 Swift `Codable` 模型迁移 DTO 名称和字段。
2. 为每个 API group 建 fixture。
3. 生成 Retrofit client。
4. 写 repository conversion test。
5. 页面逐个接入 live repository。

## 验收标准

- 所有首批接口有 DTO decode test。
- 401 行为全局一致。
- 搜索和分页支持取消旧请求。
- 上传接口不重复写 multipart 代码。

