# 13. 资讯列表、详情与发布

## iOS 来源

- `Features/Discover/News/Views/NewsModuleView.swift`
- `DiscoverNewsDetailView.swift`
- `DiscoverNewsPublishSheet.swift`
- `DiscoverNewsModels.swift`

## Flutter 目标路径

```text
lib/features/discover/news/
```

## 页面职责

- 展示资讯列表。
- 搜索资讯。
- 资讯详情。
- 发布资讯。

## 路由

```text
/app/discover/news
/news/:articleId
/news/new
```

## API

iOS 当前通过 `DiscoverNewsRepositoryAdapter` 组合 social/web service。Flutter 先抽象：

```text
NewsRepository
  fetchNews
  fetchNewsDetail
  publishNews
```

若 BFF 暂无专门资讯接口，首期可用 mock + 后端补齐契约。

## UI 复刻

- 新闻卡展示标题、摘要、封面、来源、发布时间。
- 详情页标准 push 或沉浸式视封面决定。
- 发布 sheet 使用系统导航 chrome。
- 富文本首期用纯文本/Markdown 展示。

## 状态模型

```text
NewsListState
  query
  items
  loading
  error

NewsEditorState
  title
  body
  source
  cover
  submitting
```

## 实现步骤

1. 明确 BFF 资讯契约。
2. 建 DTO 和 repository。
3. 列表接分页或 cursor。
4. 详情 loader 只收 articleId。
5. 发布表单校验标题和正文。
6. 发布成功回到列表并刷新。

## 测试

- 列表空态。
- 详情 deep link。
- 发布失败保留表单。
- 搜索 debounce。

