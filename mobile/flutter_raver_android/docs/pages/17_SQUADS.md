# 17. 小队

## iOS 来源

- `Features/Squads/SquadProfileView.swift`
- `Features/Squads/SquadProfileViewModel.swift`
- `Features/Messages` 中 group conversation

## Flutter 目标路径

```text
lib/features/circle/squads/
```

## 页面职责

- 推荐小队。
- 我的小队。
- 小队详情。
- 加入小队。
- 小队设置/管理。
- 小队消息入口。

## 路由

```text
/app/circle/squads
/squads/:squadId
/squads/:squadId/manage
```

## API

- `GET /v1/squads/recommended`
- `GET /v1/squads/mine`
- `GET /v1/squads/:id/profile`
- `POST /v1/squads/:id/join`
- `POST /v1/squads`
- `PATCH /v1/squads/:id/my-settings`
- `PATCH /v1/squads/:id/manage`

## UI 复刻

- 小队卡展示头像、旗帜、成员数、最后消息。
- 详情页展示 banner、成员、动态、设置入口。
- 管理页用标准导航表单。
- 成员点击进入 UserProfile。

## 状态模型

```text
SquadsState
  recommended
  mine
  loading
  error

SquadProfileState
  squad
  members
  activities
  joining
  error
```

## 实现步骤

1. 建 SquadRepository。
2. 小队列表并行拉 recommended/mine。
3. 详情 loader 按 squadId。
4. 加入小队乐观或提交后刷新。
5. 管理表单支持头像/旗帜上传。

## 测试

- 推荐/我的小队加载。
- 加入小队。
- 成员跳用户详情。
- 管理保存失败保留表单。

