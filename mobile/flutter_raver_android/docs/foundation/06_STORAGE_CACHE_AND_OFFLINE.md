# 06. 存储、缓存与离线

## 目标

在不拖慢首版的前提下，建立清晰的本地存储边界。首期保证登录、偏好、图片缓存和核心列表弱网体验。

## 存储分层

| 类型 | 技术 | 内容 |
|---|---|---|
| 安全存储 | `flutter_secure_storage` | token |
| 简单偏好 | `shared_preferences` | theme/language/runtime/baseURL |
| 结构化缓存 | `drift` + SQLite | events/djs/sets/feed/checkins |
| 文件缓存 | package + path provider | 上传草稿、临时媒体 |
| 图片缓存 | `cached_network_image` | remote image |

## Token

规则：

- 登录成功立即写入 secure storage。
- App 启动先读 token，再请求 `/profile/me` 验证。
- 401 清空 token 和当前用户。
- logout 清空 token、用户、pending upload task。

## 偏好

字段：

```text
runtimeMode: mock | live
bffBaseUrl
language: system | zh | en
appearance: system | light | dark
lastSelectedTab
```

## SQLite 缓存策略

首期只缓存：

- events 首屏和详情
- djs 首屏和详情
- sets 首屏和详情
- learn 静态数据

缓存规则：

- network first，失败后读 cache。
- 手动下拉刷新强制 network。
- cache 中显示 stale 提示，不假装实时。
- 编辑/删除成功后更新或清理对应 cache。

## 离线草稿

第二期再做：

- compose post draft
- event editor draft
- set editor draft
- upload pending media

草稿必须包含版本号，避免表单字段变化导致旧草稿崩溃。

## 图片缓存

规则：

- 列表缩略图使用小图 URL 或 OSS resize 参数。
- 详情 hero 使用中大图。
- avatar 使用固定尺寸。
- 失败态统一占位。

## 复刻步骤

1. 建 storage provider。
2. 实现 token store。
3. 实现 preferences store。
4. 建 drift database skeleton。
5. 先让 repository 支持 cache fallback。
6. 逐页面打开离线读取。

## 验收标准

- 断网后已浏览过的 events/djs/sets 能看到缓存。
- 退出登录清理敏感数据。
- 图片列表滚动不反复闪烁。
- cache schema 变更有 migration。

