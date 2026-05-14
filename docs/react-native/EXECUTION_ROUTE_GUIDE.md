# Raver React Native Execution Route Guide

> Status: Active draft  
> Created: 2026-05-14  
> Purpose: 作为 RN 复现 Raver 的日常执行路线文档，约束每一轮开发如何读现有 iOS 原生代码、确认需求、产出局部落地方案、跟踪进度、记录日志并防止路线漂移。

## 0. 核心原则

RN 复现不是“看到一个页面就写一个页面”，而是持续沿着一条主线推进：

```text
现有 iOS 行为
  -> 需求确认
  -> RN 迁移策略
  -> 局部落地文档
  -> 实现
  -> 验收
  -> 收口
  -> 日志记录
```

任何开发轮次都必须先回答：

- 这部分对应哪个 iOS 原生功能？
- 当前需求是复刻、改良、裁剪，还是新增？
- 是否影响 API、导航、状态、设计系统、Native 能力？
- 是否属于当前阶段核心路线？
- 是否需要用户确认后才能继续？

如果不能回答，就不能直接开写代码。

## 1. 当前核心路线

当前 RN 复现核心路线按以下顺序推进：

```text
Phase 0: 执行基线与范围冻结
Phase 1: RN 工程底座
Phase 2: Auth + App Shell + Navigation
Phase 3: Discover / Events / DJs / Sets 只读内容主链路
Phase 4: Circle / Feed / Post / Comment 社区核心
Phase 5: Profile / Check-ins / Ratings / Search
Phase 6: Notifications / Push / Deep Link
Phase 7: Messages / Tencent IM / Squads
Phase 8: Native polish / Release / Parity close
```

任何新需求必须进入以下四类之一：

| 类型 | 处理 |
|---|---|
| Core | 当前阶段必须做，进入本轮执行 |
| Support | 为 Core 服务的底座能力，可同步做 |
| Deferred | 合理但非当前阶段，记录到 backlog |
| Reject / Hold | 会引发路线漂移，暂不进入 RN 复现 |

## 2. 每一轮开发固定流程

每一轮开发都按 8 步走。

### Step 1: 选择执行单元

执行单元必须足够小，建议粒度：

- 一个页面。
- 一个 feature 的一个子能力。
- 一个基础设施能力。
- 一个 API repository。
- 一个 native bridge spike。

不建议一轮同时做：

- 多个业务域。
- 页面 + 大型 native module + API 重构。
- 设计系统全面重写。
- 与当前阶段无关的新玩法。

### Step 2: 读取 iOS 来源

每个执行单元必须先列出 iOS 来源文件。

模板：

```text
iOS source:
  - mobile/ios/RaverMVP/RaverMVP/...
  - mobile/ios/RaverMVP/RaverMVP/...

Related backend:
  - server/src/routes/...
  - server/src/modules/...

Related docs:
  - docs/...
```

读取重点：

- 页面入口。
- ViewModel。
- Repository。
- Service/API。
- 路由。
- 状态。
- loading/empty/error。
- mutation 行为。
- 权限和 native 依赖。
- 埋点、通知、deep link。

### Step 3: 提炼现有行为

每轮都要先写出“现有 iOS 行为摘要”。

模板：

```text
Current iOS behavior:
  - Entry:
  - Main states:
  - Data source:
  - User actions:
  - Navigation:
  - Error/empty/loading:
  - Native dependency:
  - Known gaps:
```

这个摘要决定 RN 是复刻、简化还是延后。

### Step 4: 判断是否需要用户确认

如果触发“必须确认项”，先问用户，不直接实现。

必须确认项见第 3 节。

如果没有触发，则按当前文档约定继续。

### Step 5: 写局部落地方案

每个执行单元必须产生或更新一份局部落地方案。

建议路径：

```text
docs/react-native/implementation/
  phase-01-foundation/
  phase-02-auth-shell/
  phase-03-discover-events-music/
  phase-04-community-feed/
  phase-05-profile-search-checkins/
  phase-06-notifications/
  phase-07-messages-squads/
```

文档命名：

```text
NN_FEATURE_OR_PAGE_NAME.md
```

例如：

```text
docs/react-native/implementation/phase-02-auth-shell/01_AUTH_FLOW.md
docs/react-native/implementation/phase-03-discover-events-music/02_EVENT_DETAIL.md
```

局部方案必须包含：

- iOS 来源文件。
- RN 目标路径。
- 当前 iOS 行为。
- RN 复刻策略。
- 需要裁剪/延后的能力。
- API/repository 设计。
- navigation route。
- state/query key。
- UI component 结构。
- 验收 checkbox。
- 风险和回滚。

### Step 6: 实现

实现时只改本轮执行单元需要的文件。

允许改：

- 当前 feature。
- 必要 shared UI。
- 必要 service/repository。
- 必要 navigation 类型。
- 对应测试。
- 对应文档和日志。

不允许顺手做：

- 与当前 feature 无关的视觉大改。
- 大范围重命名。
- 后端非必要重构。
- 把 Deferred backlog 直接变成实现。
- 删除 iOS 主线能力。

### Step 7: 验收与收口

每轮结束前必须完成：

- 更新局部方案 checkbox。
- 更新总进度 checkbox。
- 更新日志。
- 标记 Deferred / Hold 项。
- 写明未完成原因。
- 如果产生新共性能力，决定是否收口到 `shared/` 或 `services/`。

收口判断：

| 情况 | 动作 |
|---|---|
| 同一逻辑出现第二次 | 暂可保持 feature 内 |
| 同一逻辑出现第三次 | 收口到 shared/services |
| API mapper 重复 | 收口到 repository mapper |
| loading/error/empty 重复 | 收口到 shared feedback |
| navigation helper 重复 | 收口到 navigation service |
| media/upload 重复 | 收口到 media service |

### Step 8: 写开发日志

所有轮次日志写入：

[EXECUTION_LOG.md](./EXECUTION_LOG.md)

日志只记录高信号内容，不写流水账。

## 3. 必须向用户确认的需求

以下情况必须先确认。

### 3.1 产品范围确认

需要确认：

- 当前阶段是否要纳入这个功能。
- 是否允许只做 read-only。
- 是否允许延后高级能力。
- 是否要改变 iOS 现有交互。
- 是否要新增 iOS 没有的能力。

例子：

- “RN 版是否首期就要完整 IM？”
- “活动编辑器是否首期要做，还是先只做查看？”
- “发帖是否首期支持视频？”

### 3.2 业务规则确认

需要确认：

- 登录方式是否变化。
- 内容审核规则是否变化。
- 评论/删除/举报权限是否变化。
- 小队位置共享隐私规则是否变化。
- 虚拟资产是否首期启用。
- 打卡是否允许离线。

### 3.3 技术路线确认

需要确认：

- Expo Dev Client 还是 RN CLI。
- Zustand 还是 Redux Toolkit。
- Tencent IM 使用现成 RN SDK 还是自研 Native bridge。
- Android Push 用 FCM 还是国内厂商通道也要首期接入。
- 是否要保留 iOS Native 与 RN 并行。

### 3.4 后端/API 确认

需要确认：

- 是否允许新增 BFF endpoint。
- 是否允许改现有 response shape。
- 是否允许为 RN 增加聚合接口。
- 是否需要兼容旧 iOS 客户端。

原则：

```text
优先不破坏现有 iOS。
优先新增兼容字段或新增 BFF。
不为 RN 在客户端硬拼复杂业务规则。
```

### 3.5 设计和体验确认

需要确认：

- RN 是否严格复刻 iOS 视觉。
- Android 是否允许平台化调整。
- 是否保留当前毛玻璃/胶囊 Tab 风格。
- 是否统一改品牌视觉。

### 3.6 发布和商业确认

需要确认：

- RN 是替代 iOS，还是先做 Android/cross-platform。
- 首期上线平台。
- 灰度范围。
- 是否要接 Sentry/埋点/性能监控。
- 是否要保留原 iOS 作为线上主线。

## 4. 总进度追踪

### Phase 0: 执行基线与范围冻结

- [x] 确认 RN 工程路线：RN CLI。
- [x] 确认 RN 是 iOS + Android 双端并行复现，现有 iOS Native 继续作为参照主线。
- [x] 确认 P0/P1/P2 范围，首期按 Master Plan 推荐范围推进。
- [ ] 确认当前 iOS commit/branch 作为复刻基线。
- [x] 建立 implementation 文档目录。
- [x] 建立 execution log。
- [x] 建立 deferred backlog。

### Phase 1: RN 工程底座

- [x] 创建 RN 工程。
- [x] 配置 TypeScript。
- [x] 配置 lint/format/test。
- [ ] 配置路径别名。
- [x] 建立 AppProviders。
- [x] 建立 ThemeProvider。
- [x] 建立 HTTP client。
- [x] 建立 QueryClient。
- [x] 建立 secure storage。
- [x] 建立 MMKV preferences。
- [ ] 建立 shared feedback 组件。

### Phase 2: Auth + App Shell + Navigation

- [ ] 读取 iOS `AppCoordinator` / `MainTabCoordinator` / `AppState`。
- [ ] 写 Auth Flow 局部落地方案。
- [ ] 写 Navigation 局部落地方案。
- [ ] 实现 Login。
- [ ] 实现 session bootstrap。
- [ ] 实现 AuthStack。
- [ ] 实现 MainTabs。
- [ ] 实现 root detail stack。
- [ ] 实现 route type。
- [ ] 实现 pending deep link。
- [ ] 验收登录/登出/重启恢复/401。

### Phase 3: Discover / Events / DJs / Sets

- [ ] 读取 iOS Discover 源文件。
- [ ] 写 Discover Home 落地方案。
- [ ] 写 Events List/Detail 落地方案。
- [ ] 写 DJs List/Detail 落地方案。
- [ ] 写 Sets List/Detail 落地方案。
- [ ] 实现 Discover Home。
- [ ] 实现 Events List。
- [ ] 实现 Event Detail。
- [ ] 实现 favorite mutation。
- [ ] 实现 DJs List。
- [ ] 实现 DJ Detail。
- [ ] 实现 follow mutation。
- [ ] 实现 Sets List。
- [ ] 实现 Set Detail read-only。
- [ ] 验收 deep link 和列表性能。

### Phase 4: Circle / Feed / Post / Comment

- [ ] 读取 iOS Circle/Feed/PostCard 源文件。
- [ ] 写 Feed 落地方案。
- [ ] 写 Post Detail 落地方案。
- [ ] 写 Compose Post 落地方案。
- [ ] 实现 Circle Home。
- [ ] 实现 Feed FlashList。
- [ ] 实现 shared PostCard。
- [ ] 实现 Post Detail。
- [ ] 实现 Comment List。
- [ ] 实现 Comment Create。
- [ ] 实现 Like/Save/Share/Hide。
- [ ] 实现 Compose text/image。
- [ ] 验收 optimistic update 和草稿保留。

### Phase 5: Profile / Check-ins / Ratings / Search

- [ ] 读取 iOS Profile 源文件。
- [ ] 读取 iOS Search 源文件。
- [ ] 读取 iOS Check-ins/Ratings 源文件。
- [ ] 写 Profile 落地方案。
- [ ] 写 Search 落地方案。
- [ ] 写 Check-ins/Ratings 落地方案。
- [ ] 实现 Profile Me。
- [ ] 实现 Public Profile。
- [ ] 实现 Edit Profile。
- [ ] 实现 Follow List。
- [ ] 实现 Global Search。
- [ ] 实现 Recent Search。
- [ ] 实现 Check-ins read-only。
- [ ] 实现 Ratings read-only。

### Phase 6: Notifications / Push / Deep Link

- [ ] 读取 iOS Notifications 源文件。
- [ ] 写 Notification Center 落地方案。
- [ ] 写 Push Route 落地方案。
- [ ] 实现 Notification Inbox。
- [ ] 实现 unread count。
- [ ] 实现 mark read。
- [ ] 实现 push token register。
- [ ] 实现 push payload route parser。
- [ ] 验收 notification -> route。

### Phase 7: Messages / Tencent IM / Squads

- [ ] 读取 iOS Messages/TencentIM 源文件。
- [ ] 读取 iOS Squads 源文件。
- [ ] 确认 Tencent IM RN 技术路线。
- [ ] 写 IM Bootstrap spike 文档。
- [ ] 写 Conversation 落地方案。
- [ ] 写 Squads 落地方案。
- [ ] 实现 IM bootstrap。
- [ ] 实现 Messages Home。
- [ ] 实现 Conversation basic。
- [ ] 实现 Custom Card basic。
- [ ] 实现 Squad Profile read-only。
- [ ] 实现 Squad Offline Activity basic。

### Phase 8: Native polish / Release / Parity close

- [ ] Widget 策略确认。
- [ ] Media player 策略确认。
- [ ] Location background 策略确认。
- [ ] Release config。
- [ ] Sentry。
- [ ] E2E smoke。
- [ ] Performance smoke。
- [ ] Deep link smoke。
- [ ] Push smoke。
- [ ] Parity checklist close。

## 5. 局部落地文档模板

复制以下模板到 `docs/react-native/implementation/<phase>/NN_NAME.md`。

```md
# <Feature/Page> RN Implementation Plan

> Status: Draft / Active / Done / Deferred  
> Phase:  
> Owner:  
> Created:  
> Updated:

## 1. Scope

- [ ] In scope:
- [ ] Out of scope:
- [ ] Deferred:

## 2. iOS Source

```text
mobile/ios/RaverMVP/RaverMVP/...
```

## 3. Current iOS Behavior

- Entry:
- Main states:
- Data source:
- User actions:
- Navigation:
- Loading/empty/error:
- Native dependency:
- Known gaps:

## 4. User Confirmations

- [ ] No confirmation needed.
- [ ] Needs confirmation:

Decision:

## 5. RN Target

```text
src/features/...
src/shared/...
src/services/...
```

## 6. Strategy

- Reuse:
- Rebuild:
- Simplify:
- Defer:

## 7. API / Repository

- Endpoint:
- Query key:
- Mutation:
- Mapper:
- Error handling:

## 8. Navigation

- Route:
- Params:
- Deep link:
- Tab behavior:

## 9. State

- Server state:
- Global state:
- Local state:
- Persisted state:

## 10. UI Structure

```text
Screen
  Component
  Component
```

## 11. Implementation Checklist

- [ ] Files created.
- [ ] API wired.
- [ ] Loading state.
- [ ] Empty state.
- [ ] Error state.
- [ ] Refresh.
- [ ] Pagination if needed.
- [ ] Mutation if needed.
- [ ] Tests.
- [ ] Docs updated.
- [ ] Log updated.

## 12. Acceptance

- [ ] Matches iOS core behavior.
- [ ] Handles error/offline.
- [ ] Navigation works.
- [ ] Deep link works if applicable.
- [ ] Performance acceptable.

## 13. Risks / Rollback

- Risk:
- Rollback:
```

## 6. 路线漂移控制

### 6.1 新需求入口

任何新增想法都先进入：

[DEFERRED_BACKLOG.md](./DEFERRED_BACKLOG.md)

不要直接进入实现。

Backlog 记录格式：

```text
- Date:
- Request:
- Source:
- Category: Core / Support / Deferred / Hold
- Decision:
- Revisit phase:
```

### 6.2 本轮变更限制

每轮开始时写：

```text
This iteration will change:
  - ...

This iteration will not change:
  - ...
```

如果开发中发现必须越界，先更新局部方案并确认。

### 6.3 收口节奏

每个 Phase 结束前必须做一次收口：

- 删除临时重复组件。
- 收敛 shared UI。
- 收敛 repository mapper。
- 收敛 route helper。
- 更新 parity checklist。
- 更新 deferred backlog。
- 标记还债项。

不要等全部做完再统一收口。

## 7. 执行日志规则

日志写入：

[EXECUTION_LOG.md](./EXECUTION_LOG.md)

每轮日志格式：

```md
## YYYY-MM-DD - <Iteration Name>

Phase:
Scope:
iOS source reviewed:
User confirmations:
Decisions:
Changed docs:
Changed code:
Validation:
Deferred:
Risks:
Next:
```

日志要求：

- 只记录影响路线的信息。
- 不写无意义流水账。
- 所有 Deferred 必须有 revisit phase。
- 所有用户确认必须记录结论。
- 所有收口动作必须记录。

## 8. 开始执行前的首次确认清单

真正创建 RN 工程和写代码前，建议先向用户确认：

- [x] RN 路线：RN CLI。
- [x] RN 首期目标：iOS + Android 双端并行复现。
- [x] 首期是否包含完整 IM？默认不包含完整 IM，后置到 Phase 7。
- [x] 首期是否包含发帖视频？默认不包含视频发帖，首期文字/图片。
- [x] 首期是否包含小队实时定位？默认不包含，后置到 Phase 7。
- [x] 首期是否包含 Widget？默认不包含，后置到 Phase 8。
- [x] 状态管理偏好：TanStack Query + Zustand。
- [x] 是否允许新增 RN 专用 BFF 聚合接口？允许新增兼容型 BFF，不破坏 iOS 当前接口。
- [x] 是否严格复刻 iOS 视觉，还是 Android 可平台化调整？复刻 Raver 品牌，Android 交互尊重平台习惯。

默认建议：

```text
RN CLI 或 Expo Dev Client 二选一需确认。
首期不包含完整 IM、小队实时定位、Widget。
首期包含文字/图片发帖，不包含视频发帖。
状态管理默认 Zustand + TanStack Query。
允许新增兼容型 BFF，不破坏 iOS 当前接口。
视觉复刻 Raver 品牌，Android 交互尊重平台习惯。
```
