# Raver Flutter Android 文档总目录

创建日期：2026-04-19  
定位：这是 Flutter Android 复刻工程的文档总入口。`RAVER_FLUTTER_ANDROID_TECHNICAL_PLAN.md` 保持为总技术路线图；本目录下的 `foundation/` 和 `pages/` 是每个底层能力、业务板块、页面的详细施工说明。

## 阅读顺序

1. 先读总路线图：`RAVER_FLUTTER_ANDROID_TECHNICAL_PLAN.md`
2. 再读基础分册：`foundation/`
3. 最后按开发阶段读页面分册：`pages/`
4. 每完成一个页面，在 `IOS_ANDROID_PARITY_CHECKLIST.md` 更新状态

## 基础能力分册

| 文档 | 用途 |
|---|---|
| `foundation/01_ENVIRONMENT_AND_BOOTSTRAP.md` | 本机环境、Flutter 工程生成、后端联调 |
| `foundation/02_ARCHITECTURE_AND_STATE.md` | MVVM、Repository、Riverpod、UseCase 规则 |
| `foundation/03_ROUTER_AND_NAVIGATION.md` | go_router、Tab shell、sheet/fullscreen/deep link |
| `foundation/04_DESIGN_SYSTEM_AND_SHARED_UI.md` | 主题、字体、卡片、TabBar、导航 chrome、通用组件 |
| `foundation/05_NETWORKING_AND_BFF.md` | Dio、Retrofit、DTO、BFF envelope、错误处理 |
| `foundation/06_STORAGE_CACHE_AND_OFFLINE.md` | token、偏好、SQLite、图片缓存、离线策略 |
| `foundation/07_MEDIA_UPLOAD_AND_NATIVE_BRIDGE.md` | 图片/视频上传、播放器、权限、platform channel |
| `foundation/08_TESTING_RELEASE_AND_QUALITY.md` | 测试矩阵、性能、发布、验收门禁 |

## 页面与业务分册

| 阶段 | 文档 |
|---|---|
| App 基座 | `pages/00_APP_SHELL_AND_TABS.md` |
| 登录注册 | `pages/01_AUTH_LOGIN_REGISTER.md` |
| Discover 入口 | `pages/02_DISCOVER_HOME_AND_SEARCH.md` |
| 推荐 | `pages/03_DISCOVER_RECOMMEND.md` |
| 活动列表 | `pages/04_EVENTS_LIST_AND_FAVORITES.md` |
| 活动详情 | `pages/05_EVENT_DETAIL.md` |
| 活动编辑 | `pages/06_EVENT_EDITOR_AND_LINEUP_IMPORT.md` |
| DJ 列表 | `pages/07_DJS_LIST.md` |
| DJ 详情 | `pages/08_DJ_DETAIL.md` |
| DJ 导入编辑 | `pages/09_DJ_IMPORT_AND_EDITOR.md` |
| Sets 列表 | `pages/10_SETS_LIST.md` |
| Set 详情 | `pages/11_SET_DETAIL_PLAYER_TRACKLIST.md` |
| Set 编辑 | `pages/12_SET_EDITOR_TRACKLIST_EDITOR.md` |
| 资讯 | `pages/13_NEWS_LIST_DETAIL_PUBLISH.md` |
| Wiki/Learn | `pages/14_WIKI_LEARN_LABELS_FESTIVALS_RANKINGS.md` |
| 圈子首页 | `pages/15_CIRCLE_HOME.md` |
| 动态/发帖 | `pages/16_FEED_POST_DETAIL_COMPOSE.md` |
| 小队 | `pages/17_SQUADS.md` |
| 打分 | `pages/18_RATINGS.md` |
| 消息 | `pages/19_MESSAGES_CHAT_NOTIFICATIONS.md` |
| 个人中心 | `pages/20_PROFILE_ME_PUBLIC_EDIT_SETTINGS.md` |
| 打卡/发布/关注 | `pages/21_CHECKINS_PUBLISHES_FOLLOWS.md` |
| 通知/搜索/外链 | `pages/22_NOTIFICATIONS_DEEPLINKS_EXTERNAL_ACTIONS.md` |

## 文档维护规则

- 新增 Flutter 页面前，先在 `pages/` 中补页面文档。
- 页面文档必须包含：iOS 源文件、Flutter 目标路径、路由、状态模型、API、复刻步骤、测试验收。
- 如果 iOS 页面行为变化，先更新对应页面文档，再改 Flutter。
- 如果 BFF 契约变化，同时更新 `foundation/05_NETWORKING_AND_BFF.md` 和具体页面文档。

