# 02. Discover 首页与全局搜索

## iOS 来源

- `Features/Discover/DiscoverHomeView.swift`
- `Features/Discover/Search/Views/DiscoverSearchViews.swift`
- `Features/Discover/Search/ViewModels/DiscoverSearchResultsViewModels.swift`
- `Shared/RaverScrollableTabPager.swift`

## Flutter 目标路径

```text
lib/features/discover/presentation/discover_home_screen.dart
lib/features/discover/search/
```

## 页面职责

- Discover 顶层入口。
- 子栏目切换：推荐、活动、资讯、DJ、Sets、Wiki。
- 搜索入口。
- 子栏目状态保留。

## 路由

```text
/app/discover
/discover/search
/discover/search/events?q=
/discover/search/djs?q=
/discover/search/sets?q=
/discover/search/wiki?q=
```

## UI 复刻

- 顶部使用 Raver 品牌标题和搜索入口。
- 子栏目使用横向 segmented tab，颜色按 iOS Section theme color。
- Tab pager 左右滑动与点击切换都可用。
- 搜索输入页使用标准系统导航 chrome。

## API

搜索结果复用各模块列表接口：

- Events: `/v1/events?search=`
- DJs: `/v1/djs?search=`
- Sets: `/v1/dj-sets`
- Wiki: `/v1/learn/labels`, `/v1/learn/festivals`

## 状态模型

```text
DiscoverHomeState
  selectedSection
  loadedSections

DiscoverSearchState
  query
  activeCategory
  resultsByCategory
  loading
  error
```

## 实现步骤

1. 建 Discover section enum。
2. 建 `RaverSegmentedPager`。
3. 子栏目按 lazy mount 加载。
4. 建 full screen search input。
5. 搜索 debounce 300ms。
6. 用 cancel token 避免旧请求覆盖。
7. 点击结果进入公共详情 route。

## 测试

- 切换栏目不丢列表位置。
- 搜索空词不请求。
- 搜索结果点击进入正确详情。
- Android back 从搜索返回 Discover。

