# Feature 05 - Checkins Ratings Assets Search

## 1. 范围

包括：

- Check-in v2 read model。
- My check-ins。
- User gallery/stat。
- Ratings。
- Virtual assets。
- Global search。
- Share / QR / short link。

## 2. iOS 来源

```text
Features/Profile/Views/Checkins/*
Features/Profile/Views/RatingEditors/*
Features/VirtualAssets/*
Features/Search/*
Core/ShareLinkService.swift
Core/ShareLinkRepository.swift
```

## 3. RN 目标目录

```text
features/checkins/
features/ratings/
features/virtualAssets/
features/search/
features/share/
```

## 4. Check-in

当前后端主线：

```text
/v2/checkins
Check-in v2 projection read model
```

RN 首期：

- 我的 check-ins read-only。
- 用户 check-in timeline。
- event/dj check-in 状态展示。

后置：

- check-in 创建。
- 离线 check-in queue。
- projection rebuild 管理视图。

## 5. Ratings

首期：

- event rating detail。
- rating unit detail。
- 个人评分展示。

后置：

- rating editor。
- 复杂评分维度管理。

## 6. Virtual Assets

当前是身份视觉层。RN 首期只做：

- 用户卡片外观读取。
- Profile 展示。
- Chat/List 渲染基础。

后置：

- asset center。
- 装备切换。
- 高级动画。

## 7. Search

当前 iOS 有完整 global search：

```text
Features/Search/ViewModels/GlobalSearchRepository.swift
Features/Search/Storage/RecentSearchStore.swift
Features/Search/Telemetry/GlobalSearchTelemetry.swift
```

RN 需要：

- search overlay。
- result tabs。
- recent search。
- debounced query。
- cancel stale request。
- result item route。

## 8. Share

RN share flow：

1. 当前页面生成 share target。
2. 调 share repository 创建 short link / poster / QR。
3. 使用 native share sheet。
4. Universal Link 回流由 linking parser 接管。

## 9. 验收

- Search 输入快速变化不会旧请求覆盖新结果。
- 最近搜索可清除。
- check-in 页面使用 v2 projection。
- share link 打开能回到正确详情页。
- virtual asset 关闭 feature flag 后 UI 正常降级。

