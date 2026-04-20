# 03. 路由与导航

## 目标

复刻 iOS 的全局单导航语义：主站只有一个公共 push 语义，公共详情页按 ID 进入，TabBar 显隐由路由元信息决定。

## iOS 对照

- `MainTabCoordinatorView`
- `AppRouter`
- `AppRoute`
- `AppSheetRoute`
- `AppFullScreenRoute`
- `MainTabView`

## Flutter 目标

使用 `go_router`：

```text
/login
/app/discover
/app/circle
/app/messages
/app/profile
/events/:eventId
/djs/:djId
/sets/:setId
/posts/:postId
/users/:userId
/squads/:squadId
/conversations/:conversationId
/ratings/units/:unitId
```

## 路由元信息

每条 route 至少定义：

```text
name
path
hideBottomBar
requiresAuth
analyticsName
preferredTab
presentation: push | sheet | fullscreen
```

## Tab Shell

实现 `RaverShellScaffold`：

- body 使用 `StatefulShellRoute` 或 `IndexedStack`。
- 四个 Tab：Discover、Circle、Messages、Profile。
- TabBar 使用自定义 `RaverFloatingTabBar`。
- 切换 Tab 不清空已加载列表。
- 在详情页由 route meta 隐藏 TabBar。

## Sheet 与 Fullscreen

不要在页面里随手 `showModalBottomSheet`。统一封装：

```text
RaverPresentation.showSheet(route)
RaverPresentation.showFullscreen(route)
```

页面级文档需明确该页面是否是：

- 标准 push
- bottom sheet
- fullscreen
- Android external intent

## Android 返回

规则：

- 详情页：系统 back = pop。
- Tab 根页：back 切回默认 Discover 或二次确认退出。
- sheet：back 关闭 sheet。
- fullscreen player/viewer：back 退出 fullscreen，不退出详情页。
- 表单未保存：back 触发离开确认。

## Deep Link

首期支持：

```text
raver://events/:id
raver://djs/:id
raver://sets/:id
raver://posts/:id
raver://users/:id
```

流程：

1. App bootstrap。
2. 如果需要登录，先进入 login。
3. 登录后恢复 pending deep link。
4. loader screen 按 ID 拉取详情。

## 复刻步骤

1. 建 `app/router/routes.dart`。
2. 建 route metadata。
3. 建 `RaverShellScaffold` 和四 Tab 根页面。
4. 接入登录态 redirect。
5. 补公共详情 loader route。
6. 建 Android back 行为测试矩阵。

## 验收标准

- 任意公共详情页可以从多个入口进入，但只定义一个 route。
- TabBar 在指定详情页隐藏。
- Android back 行为稳定。
- deep link 能进入 loader 并展示详情。

