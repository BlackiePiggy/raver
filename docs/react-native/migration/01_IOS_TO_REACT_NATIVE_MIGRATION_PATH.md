# Migration 01 - iOS To React Native Migration Path

## 1. 迁移策略

推荐并行复现，不推荐直接替换：

```text
iOS Native remains current
RN app grows in parallel
BFF contract shared
Feature parity tracked by checklist
Gradual beta rollout
```

原因：

- 当前 iOS 是主客户端，不能被未验证 RN 版本打断。
- IM、Push、Widget、定位、播放器等风险需要分期验证。
- Raver 后端已可作为共享 BFF。

## 2. 阶段计划

### Stage 0: Inventory freeze

产物：

- iOS source file map。
- API endpoint map。
- UI parity screenshots。
- feature priority。

门禁：

- `features/00_FEATURE_MIGRATION_MATRIX.md` 完成。
- P0/P1 范围确认。

### Stage 1: RN foundation

产物：

- RN app scaffold。
- Navigation。
- Theme。
- HTTP client。
- Storage。
- Query client。
- Session store。

门禁：

- iOS/Android 模拟器可启动。
- 能请求 BFF health/current user。
- mock/live 可切换。

### Stage 2: Auth and shell

产物：

- Login。
- Auth flow。
- Main tabs。
- Deep link parser skeleton。

门禁：

- 登录、重启恢复、登出、401 过期全通过。

### Stage 3: Read-only content

产物：

- Discover。
- Events。
- DJs。
- Sets。
- Profile。

门禁：

- 主要详情页 deep link 可达。
- 列表分页和刷新稳定。

### Stage 4: Community interaction

产物：

- Circle Feed。
- Post Detail。
- Comments。
- Like/save/share。
- Compose basic。

门禁：

- 发帖和评论失败不丢草稿。
- optimistic update 可回滚。

### Stage 5: User system and notification

产物：

- Profile edit。
- Follow list。
- Check-ins read-only。
- Notification Center。
- Push registration。

门禁：

- notification -> route 全链路可用。

### Stage 6: High-risk native capabilities

产物：

- Tencent IM。
- Media player。
- Location。
- Widget。
- Advanced share/QR/poster。

门禁：

- 每项 native capability 独立灰度。
- 有 fallback 或 feature flag。

### Stage 7: Beta and replacement decision

产物：

- E2E coverage。
- crash monitoring。
- performance report。
- parity checklist close。

门禁：

- 核心路径达到 iOS parity。
- crash-free 达标。
- API error rate 达标。

## 3. 数据和 API 迁移

不迁移数据库。RN 复用现有 BFF。

需要做：

- 为 RN 建 API fixtures。
- 关键 response 用 zod 校验。
- repository mapper 测试。
- 如果发现 iOS 依赖隐式字段，补 BFF contract，而不是 RN 硬拼。

## 4. 设计迁移

步骤：

1. 提取 iOS theme token。
2. 建 RN token。
3. 先做 shared UI。
4. 再做 feature screen。
5. 用截图对比验收。

## 5. Native 迁移

优先级：

```text
Push route > Media picker/upload > Tencent IM > Location > Widget
```

每个 native module 必须：

- 有 JS facade。
- 有初始化失败处理。
- 有 feature flag。
- 有最小验收 demo screen 或 test harness。

## 6. 回滚策略

- iOS 继续保持 current。
- RN 每个高风险 feature 可远程关闭。
- Push payload 兼容 iOS 和 RN。
- Deep Link fallback 到 Web 或显示不可用页。
- IM 不可用时消息 Tab 显示降级态，不影响其他 Tab。

## 7. 团队执行建议

可以拆三条线：

- Foundation owner：导航、状态、网络、设计系统、测试。
- Content owner：Discover、Events、DJs、Sets、Search。
- Social owner：Circle、Feed、Profile、Notifications、Messages。

每条线只改自己的 feature 和 shared contract，跨 shared 变更先提 proposal。

