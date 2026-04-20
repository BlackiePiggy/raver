# 14. Wiki/Learn：风格、厂牌、电音节、榜单

## iOS 来源

- `Features/Discover/Learn/Views/LearnModuleView.swift`
- `Core/WebFeatureModels.swift` 中 Learn/Raking models

## Flutter 目标路径

```text
lib/features/discover/learn/
```

## 页面职责

- 展示电子音乐风格树。
- 厂牌列表与详情。
- 电音节列表、详情、编辑。
- 榜单列表与详情。

## 路由

```text
/app/discover/learn
/learn/labels/:labelId
/learn/festivals/:festivalId
/learn/festivals/:festivalId/edit
/learn/rankings/:boardId
```

## API

- `GET /v1/learn/genres`
- `GET /v1/learn/labels`
- `GET /v1/learn/festivals?search=`
- `POST /v1/learn/festivals`
- `PATCH /v1/learn/festivals/:id`
- `GET /v1/learn/rankings`
- `GET /v1/learn/rankings/:boardId`

## UI 复刻

- 顶部二级 tabs：风格 / 厂牌 / 电音节 / 榜单。
- 风格树首期使用可展开列表。
- 厂牌/电音节卡展示背景图、名称、国家城市、简介。
- 详情页使用 BS-01 或 BS-03，按是否有大图决定。
- 榜单详情按年份筛选。

## 状态模型

```text
LearnState
  selectedSection
  genres
  labels
  festivals
  rankings
  loadingBySection
  errorBySection
```

## 实现步骤

1. 建 LearnRepository。
2. genres 作为静态/远程树解析。
3. labels/festivals/rankings 分别懒加载。
4. 详情 route 全部 ID 化。
5. festival editor 复用通用表单和图片上传。
6. 搜索结果复用 WikiSearchResults。

## 测试

- 风格树展开/收起。
- 厂牌详情打开。
- 电音节搜索。
- 榜单年份切换。

