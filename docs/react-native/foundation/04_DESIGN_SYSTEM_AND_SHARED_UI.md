# Foundation 04 - Design System And Shared UI

## 1. 目标

复刻 Raver 的品牌体验，同时避免 RN 侧形成另一套散乱样式。

iOS 参考：

```text
Core/Theme.swift
Shared/GlassCard.swift
Shared/RaverNavigationChrome.swift
Shared/RaverSegmentedControl.swift
Shared/RaverScrollableTabPager.swift
Shared/PostCardView.swift
Shared/Feedback/*
```

## 2. 目录

```text
shared/theme/
  tokens.ts
  colors.ts
  typography.ts
  spacing.ts
  shadows.ts
  ThemeProvider.tsx

shared/ui/
  Button.tsx
  IconButton.tsx
  Avatar.tsx
  GlassCard.tsx
  SegmentControl.tsx
  TabPager.tsx
  LoadingView.tsx
  EmptyState.tsx
  ErrorState.tsx
  Skeleton.tsx
  BottomSheet.tsx

shared/components/
  PostCard.tsx
  EventCard.tsx
  DjCard.tsx
  SetCard.tsx
  UserCard.tsx
  CommunityCard.tsx
```

## 3. 设计 Token

必须集中管理：

```text
color
spacing
radius
font
shadow
zIndex
opacity
motion
```

不要在页面里随手写大量魔法值。

## 4. 字体与图标

当前仓库有字体资源：

```text
fonts/bold/altehaasgroteskbold.ttf
```

RN 侧需要：

- 明确字体授权和打包策略。
- 为中英文分别定义 fallback。
- 图标优先使用统一 icon set，不要每个 feature 自绘。

## 5. 长列表

Feed、评论、活动列表、DJ 列表、消息列表使用 FlashList。

规则：

- item key 稳定。
- 不在 renderItem 里创建复杂匿名对象。
- 图片尺寸有固定宽高或 aspect ratio。
- 骨架态高度接近真实内容。
- 分页 footer 独立组件。

## 6. 反馈状态

所有列表和详情页必须具备：

```text
loading
skeleton
empty
error
refreshing
pagination loading
mutation pending
offline hint
```

从 iOS `Shared/Feedback` 迁移为 RN shared feedback。

## 7. 组件边界

`shared/ui` 是纯 UI，不知道业务。

`shared/components/PostCard` 这种可以承载跨模块业务展示，但不能直接调用 API。互动动作通过 props 传入。

## 8. 验收

- 首页、Feed、详情页视觉风格一致。
- Light/Dark 或当前品牌主题切换不破坏布局。
- 空态/错误态文案和按钮有统一规范。
- 小屏幕不溢出。
- 长列表滚动稳定。

