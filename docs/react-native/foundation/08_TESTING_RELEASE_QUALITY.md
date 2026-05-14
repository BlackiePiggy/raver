# Foundation 08 - Testing Release Quality

## 1. 测试分层

```text
unit:
  mapper
  repository
  pure utils
  stores

component:
  PostCard
  EventCard
  loading/error/empty
  form validation

screen:
  event detail
  post detail
  profile

e2e:
  login
  discover -> event detail
  circle -> post detail -> comment
  profile edit
  notification -> deep link
```

## 2. Fixture

建立：

```text
src/testing/fixtures/
  event.fixture.ts
  dj.fixture.ts
  set.fixture.ts
  post.fixture.ts
  profile.fixture.ts
  notification.fixture.ts
```

Fixture 应来自真实 BFF response 的脱敏样本。

## 3. 性能门禁

关注：

- cold start。
- 首屏请求数。
- Feed 滚动掉帧。
- 图片内存。
- Chat 长列表。
- 搜索输入取消旧请求。
- Android back 卡顿。

## 4. 发布门禁

每次准备上线：

- lint 通过。
- typecheck 通过。
- unit/component tests 通过。
- E2E 主路径通过。
- Sentry 初始化。
- sourcemap 上传。
- API base URL 指向正确环境。
- Push entitlement / Android notification permission 配置完成。
- Deep Link / Universal Link 验证。

## 5. 灰度策略

如果 RN 将替代现有移动端：

1. 内部 TestFlight / internal track。
2. 小范围核心用户。
3. 只打开 read-only 内容能力。
4. 打开发帖/评论。
5. 打开 IM。
6. 打开高级 native 能力。

## 6. 验收

- 每个 feature 有至少一个屏幕级测试或 E2E 覆盖。
- 关键 DTO mapper 有单测。
- crash-free 和 API error rate 接入监控。
- 可以从线上配置关闭高风险 feature。

