# 06. 活动编辑与阵容图导入

## iOS 来源

- `Features/Discover/Events/Views/EventEditorView.swift`
- `Features/Discover/Events/Views/EventLineupSupport.swift`
- `Features/Discover/Events/Views/EventCalendarSupport.swift`

## Flutter 目标路径

```text
lib/features/discover/events/editor/
```

## 页面职责

- 新增/编辑活动。
- 上传封面、阵容图。
- 维护票档、阵容、舞台、Day/Week 时间。
- 从阵容图导入 lineup 草稿。

## 路由

```text
/events/new
/events/:eventId/edit
/events/lineup-import
```

编辑表单 route meta：

```text
requiresAuth: true
hideBottomBar: true
navigationChrome: system
```

## API

- `POST /v1/events`
- `PATCH /v1/events/:id`
- `DELETE /v1/events/:id`
- `POST /v1/events/upload-image`
- `POST /v1/events/lineup/import-image`
- `GET /v1/djs?search=`

## UI 复刻

- 表单分 section：基础、时间地点、媒体、票档、阵容。
- 上传后先预览。
- 阵容槽位支持添加、删除、排序。
- 时间选择器适配 Android。
- 未保存离开要确认。

## 状态模型

```text
EventEditorState
  mode: create | edit
  form
  selectedCoverFile
  selectedLineupImageFile
  ticketTiers
  lineupSlots
  uploading
  submitting
  dirty
  error
```

## 实现步骤

1. 建 editor loader，edit 模式按 id 拉取 event。
2. 建 form model 和 validation。
3. 封装 media picker。
4. 先上传图片，再提交 event。
5. 阵容导入接口 timeout 120s。
6. 导入结果进入可编辑草稿，不直接保存。
7. 添加离开确认。

## 测试

- 必填字段校验。
- 上传失败后可重试。
- 导入阵容超时/失败显示错误。
- 编辑成功后返回详情并刷新。

