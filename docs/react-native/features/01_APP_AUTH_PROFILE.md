# Feature 01 - App Auth Profile

## 1. 范围

包括：

- App bootstrap
- Auth flow
- Session
- Current user
- Profile me
- Public profile
- Edit profile
- Follow list
- Settings

## 2. iOS 来源

```text
RaverMVPApp.swift
Application/Coordinator/AppCoordinator.swift
Core/AppState.swift
Core/SessionTokenStore.swift
Features/Auth/LoginView.swift
Features/Profile/ProfileView.swift
Features/Profile/UserProfileView.swift
Features/Profile/EditProfileView.swift
Features/Profile/SettingsView.swift
Features/Profile/FollowListView.swift
Features/Profile/*ViewModel.swift
```

## 3. RN 目标目录

```text
features/auth/
features/profile/
store/sessionStore.ts
services/storage/secureStorage.ts
services/api/authApi.ts
services/api/profileApi.ts
```

## 4. 状态

全局：

```text
isBootstrapping
isLoggedIn
currentUser
accessToken
preferredLanguage
errorMessage
pendingDeepLink
```

服务端缓存：

```text
['profile', 'me']
['profile', userId]
['profile', userId, 'publishes']
['profile', userId, 'checkins']
['profile', userId, 'follows']
```

## 5. API

优先沿用：

```text
/api/auth/*
/v1 profile/user 聚合接口
```

具体 endpoint 以当前 server routes 为准，RN 侧通过 repository 隔离。

## 6. 复现步骤

1. 建立 session store 和 secure token storage。
2. 建立 AuthNavigator。
3. 登录成功写入 token，并 invalidate current user。
4. App 启动时执行 `initSession`。
5. Profile Me 用 current user + profile query。
6. Public Profile 通过 route `userId` 加载。
7. Edit Profile 使用 React Hook Form + zod。
8. Settings 负责 runtime config、语言、登出。

## 7. 验收

- 未登录进入 Login。
- 已登录重启进入 MainTabs。
- token 失效后回登录页。
- profile 页面 loading/empty/error 完整。
- 编辑资料成功后 Profile Me 和 Public Profile 缓存刷新。

