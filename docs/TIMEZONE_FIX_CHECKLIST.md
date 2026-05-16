# Timezone Fix Checklist

更新时间：2026-05-15

规则基线：

- 上传/提交/落库默认业务时区：`Asia/Shanghai`
- 展示层：一律按用户系统时区展示
- 展示绝对时间：必须标明当前展示时区
- Tracklist 播放偏移不是时区时间，不纳入真实时区展示规则

## 1. 服务端默认业务时区

- [x] `Event.timeZone` 数据库默认值改为 `Asia/Shanghai`
- [x] `server/src/utils/event-timezone.ts` 默认值改为 `Asia/Shanghai`
- [x] `server/src/controllers/event.controller.ts` 活动相关默认时区改为 `Asia/Shanghai`
- [x] `server/src/routes/bff.web.routes.ts` 活动相关默认时区改为 `Asia/Shanghai`
- [x] `server/src/routes/content-submission.routes.ts` 审核流活动默认时区改为 `Asia/Shanghai`
- [x] 通知中心偏好默认 `timezone` 改为 `Asia/Shanghai`
- [x] 账号封禁通知文案中的到期时间固定按 `Asia/Shanghai` 输出并显式写出北京时间

## 2. Web 统一时间格式化

- [x] 新增统一工具 [web/src/lib/timezone.ts](/Users/blackie/Projects/raver/web/src/lib/timezone.ts)
- [x] 支持读取系统时区
- [x] 支持输出系统时区标签
- [x] 支持统一格式化绝对日期
- [x] 支持统一格式化绝对日期时间

## 3. Web 展示层

### 已完成

- [x] 活动卡片 [web/src/components/EventCard.tsx](/Users/blackie/Projects/raver/web/src/components/EventCard.tsx)
- [x] 通知页 [web/src/app/notifications/page.tsx](/Users/blackie/Projects/raver/web/src/app/notifications/page.tsx)
- [x] DJ Set 播放器 [web/src/components/DJSetPlayer.tsx](/Users/blackie/Projects/raver/web/src/components/DJSetPlayer.tsx)
- [x] Tracklist 选择器 [web/src/components/TracklistSelectorModal.tsx](/Users/blackie/Projects/raver/web/src/components/TracklistSelectorModal.tsx)
- [x] 评论区超 7 天 fallback 日期 [web/src/components/CommentSection.tsx](/Users/blackie/Projects/raver/web/src/components/CommentSection.tsx)
- [x] 我的 Sets [web/src/app/my-sets/page.tsx](/Users/blackie/Projects/raver/web/src/app/my-sets/page.tsx)
- [x] 我的发布 [web/src/app/my-publishes/page.tsx](/Users/blackie/Projects/raver/web/src/app/my-publishes/page.tsx)
- [x] 我的活动 [web/src/app/events/my/page.tsx](/Users/blackie/Projects/raver/web/src/app/events/my/page.tsx)
- [x] 管理后台概览 [web/src/app/admin/page.tsx](/Users/blackie/Projects/raver/web/src/app/admin/page.tsx)
- [x] 账号删除后台 [web/src/app/admin/account-deletions/page.tsx](/Users/blackie/Projects/raver/web/src/app/admin/account-deletions/page.tsx)
- [x] 账号管控后台 [web/src/app/admin/account-enforcements/page.tsx](/Users/blackie/Projects/raver/web/src/app/admin/account-enforcements/page.tsx)
- [x] 内容举报后台 [web/src/app/admin/content-reports/page.tsx](/Users/blackie/Projects/raver/web/src/app/admin/content-reports/page.tsx)
- [x] 通知中心后台 [web/src/app/admin/notification-center/page.tsx](/Users/blackie/Projects/raver/web/src/app/admin/notification-center/page.tsx)
- [x] OpenIM 后台 [web/src/app/community/openim/page.tsx](/Users/blackie/Projects/raver/web/src/app/community/openim/page.tsx)
- [x] 签到页 [web/src/app/checkins/page.tsx](/Users/blackie/Projects/raver/web/src/app/checkins/page.tsx)
- [x] Sets 列表页 [web/src/app/sets/page.tsx](/Users/blackie/Projects/raver/web/src/app/sets/page.tsx)
- [x] DJ 列表最近作品日期 [web/src/app/djs/page.tsx](/Users/blackie/Projects/raver/web/src/app/djs/page.tsx)
- [x] DJ 详情 Sets 列表 [web/src/app/djs/[djId]/sets/page.tsx](/Users/blackie/Projects/raver/web/src/app/djs/[djId]/sets/page.tsx)
- [x] 活动列表页 [web/src/app/events/page.tsx](/Users/blackie/Projects/raver/web/src/app/events/page.tsx)
- [x] 活动详情页 [web/src/app/events/[id]/page.tsx](/Users/blackie/Projects/raver/web/src/app/events/[id]/page.tsx)
- [x] 活动 routine 页 [web/src/app/events/[id]/routine/page.tsx](/Users/blackie/Projects/raver/web/src/app/events/[id]/routine/page.tsx)

### 说明

- [x] `web/src/app/events/[id]/page.tsx` 和 `routine/page.tsx` 仍保留部分 `toLocale*`，但已经显式使用系统时区，不再固定上海时区
- [x] `web/src/lib/timezone.ts` 内部仍使用 `toLocale*`，这是统一工具实现本身，属于保留项

## 4. Web 上传/编辑入口

- [x] 活动发布页显式提交 `timeZone`
- [x] 活动发布页默认业务时区为 `Asia/Shanghai`
- [x] 活动发布页显示“展示按系统时区、保存默认北京时间”的说明
- [x] 活动编辑页显式提交 `timeZone`
- [x] 活动编辑页默认业务时区为 `Asia/Shanghai`
- [x] 活动编辑页加载既有活动时沿用活动自身 `timeZone`
- [x] 发布/编辑页日期解析不再直接依赖 `new Date('YYYY-MM-DD')` 的 UTC 语义

## 5. iOS

### 已完成

- [x] 活动编辑器默认业务时区改为 `Asia/Shanghai`
- [x] 编辑既有活动时沿用活动自身 `timeZone`
- [x] 活动编辑器继续展示设备时区与事件时区差异
- [x] `Date+Formatting.swift` 常用绝对日期格式增加系统时区标签
- [x] `Date+Formatting.swift` 常用绝对日期时间格式增加系统时区标签
- [x] 账号状态相关独立 formatter 改为复用统一格式
- [x] 清理一处 EventDetail 中因统一格式引入的时区重复显示
- [x] 全量检查 iOS 其他手写 `DateFormatter()` 的绝对时间展示点，逐步改为统一格式或明确归类
- [x] `EventDetailView.swift` 高优先级自定义时间展示已接入系统时区标签
- [x] `EventPresentationSupport.swift` 活动卡片日期区间改为统一系统时区标签格式
- [x] `DJsModuleView.swift` 当前演出时间保留紧凑 formatter，但展示文案已追加系统时区标签
- [x] `ProfileView.swift` / `SettingsView.swift` / `Models.swift` 账号、缓存、资料相关绝对时间接入统一格式
- [x] `LearnModuleView.swift` 日期区间接入统一格式
- [x] `DemoAlignedChatSearchResultsViewController.swift` 搜索结果绝对时间接入统一格式
- [x] `RaverChatCollectionDataSource.swift` 聊天时间分隔符接入系统时区标签

## 6. 明确不改/不属于此规则

- [x] Tracklist `0:00 / 1:23 / 01:02:03` 为播放偏移，不加时区
- [x] `Date.now()` 用于文件名、object key、去重 key、缓存 TTL，不属于展示时间
- [x] 相对时间如“刚刚”“3 分钟前”“2 小时前”可不标注时区
- [x] iOS `Date+Formatting.swift` 内部 formatter 是统一格式化工具实现本身，保留
- [x] iOS `chatTimeText` 仅返回紧凑时分，已由需要绝对展示的调用方追加系统时区标签
- [x] iOS `EventEditorView.swift` 的 `yyyy-MM-dd` / `HH:mm` formatter 用于编辑器内部 day key、解析、事件时区下的输入草稿，不作为独立绝对时间展示
- [x] iOS `EventDetailView.swift` / `MyCheckinsView.swift` 的 `yyyy-MM-dd` formatter 用于签到、日程分组 key，不直接展示
- [x] iOS 活动日程时间轴中的 `h a` / `HH:mm` 为同一日程面板内的刻度和卡片局部时间，面板日期副标题已标注系统时区

## 7. 验证

- [x] `web` TypeScript 检查通过：`npx tsc --noEmit`
- [x] `server` TypeScript 检查通过：`npx tsc --noEmit`
- [x] iOS 编译级验证通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- [ ] 多系统时区人工回归未在本轮执行

## 8. 本轮未完全关闭的尾项

- [x] iOS 绝对时间展示第二轮全量扫尾完成，剩余 formatter 已归类
- [x] 针对 iOS `DateFormatter/timeStyle/dateStyle` 的专项扫描已执行
- [ ] 多系统时区人工回归仍建议执行（东京、上海、洛杉矶至少三组）
