# 12. Set 编辑与 Tracklist 编辑

## iOS 来源

- `Features/Discover/Sets/Views/SetsModuleView.swift`
- `DJSetEditorView`
- `TracklistEditorView`
- `UploadTracklistSheet`

## Flutter 目标路径

```text
lib/features/discover/sets/editor/
lib/features/discover/sets/tracklist_editor/
```

## 页面职责

- 新建/编辑 Set。
- 上传缩略图和视频。
- 绑定 DJ、活动。
- 编辑 tracks。
- 上传/创建 tracklist。

## 路由

```text
/sets/new
/sets/:setId/edit
/sets/:setId/tracklists/new
/sets/:setId/tracklists/:tracklistId/edit
```

## API

- `POST /v1/dj-sets`
- `PATCH /v1/dj-sets/:id`
- `DELETE /v1/dj-sets/:id`
- `PUT /v1/dj-sets/:id/tracks`
- `POST /v1/dj-sets/:id/tracklists`
- `POST /v1/dj-sets/upload-thumbnail`
- `POST /v1/dj-sets/upload-video`
- `GET /v1/djs?search=`
- `GET /v1/events?search=`

## UI 复刻

- 表单分基础、媒体、关联、tracks。
- 视频选择后展示文件名、大小、预览。
- tracks 支持逐条编辑和批量粘贴解析。
- 绑定 DJ/Event 用搜索 sheet。
- 未保存离开确认。

## 状态模型

```text
SetEditorState
  form
  selectedThumbnail
  selectedVideo
  boundDj
  boundEvent
  tracks
  uploading
  submitting
  dirty
```

## 实现步骤

1. edit 模式按 setId 加载。
2. 建 tracks parser。
3. 上传媒体获得 URL。
4. create/patch Set。
5. replace tracks。
6. tracklist 新建接口提交文本和 tracks。

## 测试

- 批量粘贴 tracklist 解析。
- 上传视频失败可重试。
- 绑定 DJ/Event 搜索。
- 保存后返回 SetDetail 并刷新。

