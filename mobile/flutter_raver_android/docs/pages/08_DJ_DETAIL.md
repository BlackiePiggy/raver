# 08. DJ 详情

## iOS 来源

- `Features/Discover/DJs/Views/DJsModuleView.swift` 中 `DJDetailView`
- `EventDetailTabBarView.swift` 的详情 tab 思路

## Flutter 目标路径

```text
lib/features/discover/djs/detail/
```

## 页面职责

- 展示 DJ banner、头像、名称、国家、简介。
- 关注/取消关注。
- 展示 Sets、活动、评分单位、打卡记录。
- 入口到编辑和 check-in。

## 路由

```text
/djs/:djId
```

route meta：

```text
hideBottomBar: true
navigationChrome: immersiveFloating
```

## API

- `GET /v1/djs/:id`
- `GET /v1/djs/:id/sets`
- `GET /v1/djs/:id/events`
- `GET /v1/djs/:id/follow-status`
- `POST /v1/djs/:id/follow`
- `DELETE /v1/djs/:id/follow`
- `GET /v1/djs/:id/rating-units`
- `GET /v1/checkins?djID=`

## UI 复刻

- Banner hero + avatar overlap。
- 悬浮返回。
- 关注按钮使用 primary/secondary 状态。
- 子 tab：简介 / Sets / 活动 / 打卡 / 打分。
- Sets 和活动卡复用对应组件。

## 状态模型

```text
DjDetailState
  dj
  isFollowing
  sets
  events
  ratingUnits
  checkins
  selectedTab
  loading
  error
```

## 实现步骤

1. 建 loader route。
2. 首屏加载 DJ。
3. 并行或懒加载关联数据。
4. 实现 follow 乐观更新。
5. 从 Sets/Events 进入公共详情。
6. 支持编辑入口。

## 测试

- deep link 打开 DJ。
- follow 成功/失败回滚。
- tab 内容加载失败可重试。
- back 行为正确。

