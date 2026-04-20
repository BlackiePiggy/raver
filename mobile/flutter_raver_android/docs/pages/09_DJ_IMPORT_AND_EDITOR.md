# 09. DJ 导入与编辑

## iOS 来源

- `Features/Discover/DJs/Views/DJsModuleView.swift`
- Spotify/Discogs import 相关 View

## Flutter 目标路径

```text
lib/features/discover/djs/editor/
lib/features/discover/djs/import/
```

## 页面职责

- 从 Spotify 搜索并导入 DJ。
- 从 Discogs 搜索并导入 DJ。
- 手动导入 DJ。
- 编辑 DJ 基础信息和图片。

## 路由

```text
/djs/import
/djs/:djId/edit
```

## API

- `GET /v1/djs/spotify/search?q=&limit=`
- `POST /v1/djs/spotify/import`
- `GET /v1/djs/discogs/search?q=&limit=`
- `GET /v1/djs/discogs/artists/:artistId`
- `POST /v1/djs/discogs/import`
- `POST /v1/djs/manual/import`
- `PATCH /v1/djs/:id`
- `POST /v1/djs/upload-image`

## UI 复刻

- 导入方式使用 segmented control。
- 搜索候选列表显示平台头像、名称、匹配状态。
- 已匹配本地 DJ 时提示进入详情或更新。
- 编辑页分基础、媒体、平台链接。
- 上传头像/banner 前先本地预览。

## 状态模型

```text
DjImportState
  mode: spotify | discogs | manual
  query
  candidates
  selectedCandidate
  loading
  importing
  error

DjEditorState
  form
  selectedAvatar
  selectedBanner
  uploading
  submitting
```

## 实现步骤

1. 建 import repository。
2. 搜索接口 debounce。
3. 候选详情可展开。
4. import 成功后跳 DJ detail。
5. edit 模式先拉取 DJ。
6. 图片先上传再 patch。

## 测试

- Spotify 搜索空词不请求。
- Discogs 候选详情加载。
- 手动导入必填校验。
- 编辑上传失败不丢表单。

