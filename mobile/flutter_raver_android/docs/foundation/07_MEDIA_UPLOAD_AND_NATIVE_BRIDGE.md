# 07. 媒体、上传与原生桥接

## 目标

复刻 iOS 的图片、视频、上传、全屏浏览和横竖屏体验。能用成熟插件解决的，不先写 platform channel。

## iOS 对照

- `ImageLoaderView.swift`
- `RemoteCoverImage.swift`
- `ComposePostView.swift`
- `EventEditorView.swift`
- `SetsModuleView.swift`
- `RaverMVPApp.swift` 中的 `AppOrientationLock`
- `Vendor/KSPlayerLite`

## Flutter 插件

| 能力 | 插件 |
|---|---|
| 图片选择 | `image_picker` |
| 权限 | `permission_handler` |
| 图片缓存 | `cached_network_image` |
| 视频播放 | `video_player` + `chewie` |
| 音频预览 | `just_audio` |
| 外链 | `url_launcher` |
| 文件路径 | `path_provider` |

## 上传流程

统一服务：

```text
UploadRepository
  uploadEventImage
  uploadPostImage
  uploadPostVideo
  uploadDjImage
  uploadSetThumbnail
  uploadSetVideo
  uploadRatingImage
```

流程：

1. 用户选择媒体。
2. 本地校验大小、MIME、时长。
3. 本地预览。
4. 点击提交时上传。
5. 上传成功获得 URL。
6. 再提交业务表单。
7. 失败保留本地选择并允许重试。

## 视频播放器

首期：

- 使用 `video_player` 加 `chewie`。
- 支持 mp4/mov/webm/m3u8 中 BFF 当前可直连格式。
- 列表不自动播放。
- 详情页点击后播放。
- 全屏时允许横屏。

如遇到缓存、HLS 高级能力或后台播放要求：

- 评估 Android Media3 platform view。
- bridge 放在 `core/platform/media3_player`。

## 权限

Android 权限按需申请：

- 相册/图片
- 相机
- 通知
- 定位

不要启动时一次性申请全部权限。

## 原生桥接边界

只在以下情况使用 platform channel：

- 横竖屏控制插件无法满足。
- Android share/map/calendar intent 需要细节控制。
- 推送厂商通道。
- Media3 播放器。

## 复刻步骤

1. 建 `core/platform/permissions`。
2. 建 `core/media/raver_media_picker`。
3. 建 `UploadRepository`。
4. 在 Compose/Event/DJ/Set/Rating 页面接入。
5. 建 fullscreen viewer/player。
6. 真机验证权限和上传。

## 验收标准

- 上传失败不会丢表单。
- 全屏播放器 back 行为正确。
- 权限拒绝后有可恢复路径。
- release 不打印本地文件路径和 token。

