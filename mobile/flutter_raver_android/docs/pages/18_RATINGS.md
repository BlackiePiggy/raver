# 18. 打分

## iOS 来源

- `Features/MainTabView.swift` 中 Ratings 相关视图
- `Features/Profile/Views/RatingEditors/RatingEditors.swift`
- `Core/WebFeatureService.swift` rating methods

## Flutter 目标路径

```text
lib/features/circle/ratings/
```

## 页面职责

- 打分事件列表。
- 打分事件详情。
- 打分单位详情。
- 评论评分。
- 创建/编辑打分事件和单位。

## 路由

```text
/app/circle/ratings
/ratings/events/:eventId
/ratings/units/:unitId
/ratings/events/new
/ratings/events/:eventId/units/new
```

## API

- `GET /v1/rating-events`
- `GET /v1/events/:id/rating-events`
- `GET /v1/rating-events/:id`
- `POST /v1/rating-events`
- `POST /v1/rating-events/from-event`
- `PATCH /v1/rating-events/:id`
- `DELETE /v1/rating-events/:id`
- `POST /v1/rating-events/:id/units`
- `GET /v1/rating-units/:id`
- `PATCH /v1/rating-units/:id`
- `DELETE /v1/rating-units/:id`
- `POST /v1/rating-units/:id/comments`
- `POST /v1/rating/upload-image`

## UI 复刻

- 打分事件卡展示名称、封面、单位数、参与度。
- 单位详情可打分/评论。
- 编辑页分基础、单位、图片。
- 与 Event/DJ 详情互相跳转。

## 状态模型

```text
RatingsState
  events
  loading
  error

RatingUnitDetailState
  unit
  comments
  myRating
  submittingComment
```

## 实现步骤

1. 建 RatingsRepository。
2. 列表接 rating-events。
3. 详情 ID 化。
4. 评论/评分提交。
5. 编辑器复用 upload service。
6. 从 EventDetail 进入关联 rating event。

## 测试

- 打分事件列表。
- 单位详情 deep link。
- 评论提交。
- 编辑保存。

