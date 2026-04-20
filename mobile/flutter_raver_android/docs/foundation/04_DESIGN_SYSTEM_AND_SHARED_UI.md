# 04. 设计系统与共享 UI

## 目标

让 Flutter Android 不是 Material 默认皮肤，而是复刻 Raver iOS 的品牌感：深浅色动态主题、胶囊 TabBar、沉浸式详情页、统一卡片和导航 chrome。

## iOS 对照

- `Core/Theme.swift`
- `Shared/RaverNavigationChrome.swift`
- `Shared/GlassCard.swift`
- `Shared/ImageLoaderView.swift`
- `Shared/RemoteCoverImage.swift`
- `Shared/RaverScrollableTabPager.swift`
- `Shared/PrimaryButtonStyle.swift`

## Flutter 目标路径

```text
lib/core/design_system/
  raver_colors.dart
  raver_typography.dart
  raver_spacing.dart
  raver_radii.dart
  raver_motion.dart
  raver_theme.dart
lib/core/widgets/
  raver_card.dart
  raver_remote_image.dart
  raver_tab_bar.dart
  raver_navigation_chrome.dart
  raver_loading.dart
  raver_empty_state.dart
  raver_error_state.dart
```

## Token 迁移

从 iOS `RaverTheme` 提取：

- background light/dark
- card light/dark
- card border
- primary/secondary text
- accent
- tab bar chrome gradient
- tab selection gradient
- tab bar shadows

从 `DESIGN_SYSTEM.md` 提取：

- purple/blue/green/pink/cyan accent
- spacing 4/8/12/16/20/24/32
- radius 6/8/12/16/24
- transition 150/200/300ms

## 字体

- 品牌标题：复用 `fonts/bold/altehaasgroteskbold.ttf` 或 iOS 资源中的同名字体。
- 正文：Android 系统字体。
- 不用 viewport 字体缩放；支持系统 font scale。

## 页面组件复刻

必须先做：

- `RaverFloatingTabBar`
- `RaverSystemNavigation`
- `RaverImmersiveFloatingNavigationChrome`
- `RaverGradientNavigationChrome`
- `RaverRemoteImage`
- `RaverCard`
- `RaverSegmentedTabs`
- `RaverPagedList`
- `RaverActionButton`

## 详情页视觉规则

- Hero 图必须有稳定 aspect ratio。
- 返回按钮悬浮在安全区内。
- Pinned tab/header 不能遮挡内容。
- 底部操作区避开 Android navigation bar。
- 图片失败态要有占位，不允许空白跳动。

## 复刻步骤

1. 先建 theme extension 和 token。
2. 建通用组件并写 widget/golden test。
3. 每个页面只使用 design system 组件，不私写色值。
4. 对 light/dark 分别截图。
5. 在页面文档写明使用哪种 navigation chrome。

## 验收标准

- 常见页面没有散落硬编码色值。
- light/dark 下文字对比度足够。
- TabBar 与 iOS 结构一致。
- 列表滚动中没有布局跳动。

