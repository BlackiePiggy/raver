# 21. 打卡、我的发布与关注列表

## iOS 来源

- `Features/Profile/Views/Checkins/MyCheckinsView.swift`
- `Features/Profile/Views/Publishes/MyPublishesView.swift`
- `Features/Profile/FollowListView.swift`
- `Features/Profile/FollowListViewModel.swift`

## Flutter 目标路径

```text
lib/features/profile/checkins/
lib/features/profile/publishes/
lib/features/profile/follows/
```

## 页面职责

- 我的活动/DJ 打卡。
- 用户打卡记录。
- 我的发布：活动、Set、打分、资讯。
- 关注/粉丝/朋友列表。

## 路由

```text
/profile/checkins
/users/:userId/checkins
/profile/publishes
/users/:userId/followers
/users/:userId/following
/users/:userId/friends
```

## API

- `GET /v1/checkins`
- `POST /v1/checkins`
- `PATCH /v1/checkins/:id`
- `DELETE /v1/checkins/:id`
- `GET /v1/publishes/me`
- `GET /v1/users/:id/followers`
- `GET /v1/users/:id/following`
- `GET /v1/users/:id/friends`

## UI 复刻

- Checkins 按年份/月或类型分组。
- 打卡卡片点击进入 Event/DJ。
- 发布记录按类型分 tab。
- 关注列表展示用户头像、名称、关注态按钮。

## 状态模型

```text
CheckinsState
  type
  items
  page
  totalPages
  loading

FollowListState
  kind
  users
  nextCursor
  loading
```

## 实现步骤

1. 建 CheckinsRepository。
2. MyCheckins 使用 type filter。
3. 用户 checkins 用 userId。
4. MyPublishes 接 `/publishes/me`。
5. Follow list cursor 分页。
6. 用户卡 follow 操作后局部更新。

## 测试

- 打卡列表分页。
- 删除打卡。
- 发布记录点击详情。
- 关注列表分页和 follow。

