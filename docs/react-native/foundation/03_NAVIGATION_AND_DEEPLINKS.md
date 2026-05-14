# Foundation 03 - Navigation And Deep Links

## 1. 对齐 iOS 当前路由

iOS 当前核心路由在：

```text
mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift
```

RN 需要复刻这些语义：

```text
discover
circle
messages
profile
conversation
postDetail
eventDetail
newsDetail
eventSchedule
eventLiveDiscussion
eventRoute
djDetail
labelDetail
festivalDetail
setDetail
rankingBoardDetail
userProfile
squadProfile
squadManage
squadOfflineActivity
squadOfflineActivityHistory
circleIDDetail
ratingEventDetail
ratingUnitDetail
globalSearchResults
```

## 2. 推荐导航结构

```text
RootNavigator
  AuthStack
    Login
    Register
    PhoneCode
  AppStack
    MainTabs
      DiscoverStack
      CircleStack
      MessagesStack
      ProfileStack
    DetailStack
      EventDetail
      DjDetail
      SetDetail
      PostDetail
      UserProfile
      SquadProfile
      Conversation
      GlobalSearchResults
    ModalStack
      ComposePost
      EditProfile
      ChatSettings
      SharePanel
```

原则：

- Tab 根页面保留状态。
- 大部分详情页走 root stack，避免每个 Tab 维护重复详情页。
- Modal、sheet、fullscreen 明确建模。
- 不做过深嵌套。

## 3. Route 类型

```ts
export type RootStackParamList = {
  Auth: undefined;
  Main: undefined;
  EventDetail: { eventId: string };
  DjDetail: { djId: string };
  SetDetail: { setId: string };
  PostDetail: { postId: string };
  UserProfile: { userId: string };
  SquadProfile: { squadId: string };
  Conversation: { target: ChatRouteTarget };
  GlobalSearchResults: { query: string; initialTab?: string };
};
```

规则：

- 路由参数优先传 ID，不传大对象。
- 需要跨模块打开时走 navigation service。
- Deep Link 和 Push notification 都转换成同一组 route params。

## 4. Tab 行为

对齐 iOS `preferredTab` 和 `hidesTabBar`：

| Route | Preferred Tab | Tab Bar |
|---|---|---|
| Discover root | Discover | show |
| Circle root | Circle | show |
| Messages root | Messages | show |
| Profile root | Profile | show |
| Event/DJ/Set/Search | Discover | hide |
| Post/Circle ID/Rating | Circle | hide |
| Conversation/Notifications/Squad activity | Messages | hide |
| User profile | Profile | hide |

## 5. Deep Link

建议路径：

```text
raver://events/:eventId
raver://djs/:djId
raver://sets/:setId
raver://posts/:postId
raver://users/:userId
raver://squads/:squadId
raver://conversations/:conversationId
raver://search?q=
https://raver.app/s/:shareCode
```

Universal Link 处理：

1. 收到 URL。
2. 如果是 share short link，调用 share resolve API。
3. 得到 canonical deeplink。
4. 转换为 RN route。
5. 如果未登录且 route 需要登录，缓存 pending route，登录后继续。

## 6. Push Notification 路由

Notification Center payload 应转换为：

```text
NotificationRouteTarget
  -> AppRoute
  -> navigation.navigate(...)
```

不要在 push handler 里直接写页面逻辑。

## 7. 验收

- 四个 Tab 可切换且状态保留。
- 从任意 Tab 进入详情页时 Tab bar 隐藏规则一致。
- Android back、iOS swipe back 正常。
- Universal Link、push、站内点击复用同一套 route parser。
- 未登录 deep link 登录后能恢复。

