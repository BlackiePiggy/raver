# 15. 圈子首页

## iOS 来源

- `Features/MainTabView.swift` 中 `CircleHomeView`
- `Features/Circle/Coordinator/CircleCoordinator.swift`

## Flutter 目标路径

```text
lib/features/circle/presentation/circle_home_screen.dart
```

## 页面职责

- 圈子 Tab 根页。
- 子栏目：动态、小队、ID、打分。
- 保留每个子栏目状态。

## 路由

```text
/app/circle
/app/circle/feed
/app/circle/squads
/app/circle/ids
/app/circle/ratings
```

## UI 复刻

- 横向 tab pager。
- 子栏目颜色对齐 iOS：feed 红、squads 蓝、ids 紫、ratings 黄。
- 顶部不使用营销说明，直接进入内容。

## 状态模型

```text
CircleHomeState
  selectedSection
  loadedSections
```

## 实现步骤

1. 建 Circle section enum。
2. 建 pager。
3. 接 Feed/Squads/IDs/Ratings 子页面。
4. 公共详情用 App route。

## 测试

- 切换子栏目保留状态。
- back 从子页面返回 Circle。
- Tab 根页再次点击可滚到顶部，后续可做。

