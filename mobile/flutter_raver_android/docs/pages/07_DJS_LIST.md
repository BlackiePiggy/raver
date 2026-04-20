# 07. DJ 列表

## iOS 来源

- `Features/Discover/DJs/Views/DJsModuleView.swift`
- `Features/Discover/DJs/ViewModels/DJsModuleViewModel.swift`

## Flutter 目标路径

```text
lib/features/discover/djs/list/
```

## 页面职责

- DJ 列表。
- 搜索 DJ。
- 排序：热门、名称、新增等。
- 点击进入 DJ 详情。
- 入口到 DJ 导入/编辑。

## 路由

```text
/app/discover/djs
/djs/:djId
/djs/import
```

## API

- `GET /v1/djs?page=&limit=&search=&sortBy=`
- `GET /v1/learn/rankings`

## UI 复刻

- 搜索栏置顶。
- 排序使用 segmented control。
- DJ 卡展示头像、名称、国家、风格/统计、关注态。
- 头像固定尺寸，使用小图 URL。
- 支持下拉刷新和分页。

## 状态模型

```text
DjsListState
  search
  sortBy
  items
  rankingBoards
  page
  totalPages
  loading
  loadingMore
  error
```

## 实现步骤

1. 建 `DjsRepository`。
2. 建 `DjsListViewModel`。
3. 接列表分页。
4. 搜索 debounce。
5. 排序变化重载。
6. 卡片点击进入 `/djs/:id`。
7. 根据权限显示导入按钮。

## 测试

- 搜索结果正确刷新。
- 分页无重复。
- 点击 DJ 详情。
- 排序切换重置页码。

