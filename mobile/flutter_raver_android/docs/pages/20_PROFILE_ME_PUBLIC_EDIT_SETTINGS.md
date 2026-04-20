# 20. 个人中心、用户主页、编辑资料与设置

## iOS 来源

- `Features/Profile/ProfileView.swift`
- `Features/Profile/UserProfileView.swift`
- `Features/Profile/EditProfileView.swift`
- `Features/Profile/SettingsView.swift`
- `Features/Profile/ProfileViewModel.swift`
- `Features/Profile/UserProfileViewModel.swift`

## Flutter 目标路径

```text
lib/features/profile/
```

## 页面职责

- 我的主页。
- 他人主页。
- 编辑资料。
- 设置语言、主题、运行模式。
- 关注/取消关注。
- 进入关注列表、打卡、发布记录。

## 路由

```text
/app/profile
/users/:userId
/profile/edit
/profile/settings
```

## API

- `GET /v1/profile/me`
- `PATCH /v1/profile/me`
- `POST /v1/profile/me/avatar`
- `GET /v1/users/:id/profile`
- `POST /v1/social/users/:id/follow`
- `DELETE /v1/social/users/:id/follow`

## UI 复刻

- Profile header 展示头像、昵称、bio、统计。
- 我的主页显示编辑/设置入口。
- 他人主页显示关注/私信入口。
- 设置页使用标准列表。
- 编辑资料支持头像上传。

## 状态模型

```text
ProfileState
  me
  stats
  loading
  error

UserProfileState
  user
  isFollowing
  posts
  checkins
```

## 实现步骤

1. 建 ProfileRepository。
2. Me 页面接 `/profile/me`。
3. UserProfile loader 按 userId。
4. follow 乐观更新。
5. edit profile 先上传头像再 patch。
6. settings 写入 preferences 并刷新 AppState。

## 测试

- 我的主页加载。
- 他人主页 deep link。
- 编辑资料保存。
- 语言/主题切换即时生效。

