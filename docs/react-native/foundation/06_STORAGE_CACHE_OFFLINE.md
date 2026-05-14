# Foundation 06 - Storage Cache Offline

## 1. 存储分层

```text
Secure storage:
  access token
  refresh token

MMKV:
  runtime config
  language
  theme
  feature flags
  unread snapshot
  recent search
  compose draft metadata

Query cache:
  server data
  list/detail cache

File cache:
  images
  uploaded media temp files
  chat media temp files
```

## 2. Token

使用 Keychain/Keystore 封装，JS 层只通过 `SessionRepository` 访问。

流程：

1. App 启动读取 token。
2. 如果 token 存在，尝试拉取 current user。
3. 如果失败且 refresh 可用，刷新 token。
4. 如果仍失败，清空 session。

## 3. Query Cache

服务端数据使用 TanStack Query cache。

首期建议只做内存缓存，二期再做持久化：

- Discover 首屏。
- Event/DJ/Set 详情。
- Feed 首页。
- Profile。
- Notification unread。

## 4. Draft

需要持久化的草稿：

```text
compose post
comment draft
profile edit draft
event route draft
check-in draft
```

草稿必须包含版本号，避免结构升级后解析失败。

## 5. Recent Search

当前 iOS 有：

```text
Features/Search/Storage/RecentSearchStore.swift
```

RN 对应：

```text
features/search/store/recentSearchStore.ts
```

## 6. Offline

首期只做弱离线：

- 已加载页面可继续查看缓存。
- 无网络时显示 offline banner。
- 发帖/上传不做离线队列，只保留草稿。

二期再做：

- check-in 离线队列。
- feed mutation retry queue。
- chat 最近会话缓存。
- media temp cleanup scheduler。

## 7. 验收

- app 重启后 session 能恢复。
- token 清除后回登录页。
- 最近搜索保留。
- 发帖草稿不丢。
- 离线时已加载详情仍可查看。

