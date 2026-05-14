# Foundation 07 - Native Integrations

## 1. 原则

RN 能稳定覆盖的能力直接用 RN 库。质量或 SDK 能力不足时，用 Native module。

Raver 必须谨慎处理：

```text
Tencent IM
Push
Universal Link
Share
Image / video picker
Media upload
Audio / video playback
Location
Widget
Notification service extension
```

## 2. Tencent IM

当前主线：

```text
server/src/routes/tencent-im.routes.ts
server/src/modules/im/
mobile/ios/RaverMVP/RaverMVP/Infrastructure/TencentIM/
mobile/ios/RaverMVP/RaverMVP/Features/Messages/
```

RN 方案：

```text
services/im/
  tencentImBootstrap.ts
  tencentImClient.ts
  conversationRepository.ts
  messageRepository.ts

native/modules/TencentIM/
  ios/
  android/
```

分期：

1. BFF bootstrap：获取 usersig、user mapping、unread。
2. 会话列表：先 API/SDK 只读。
3. Chat UI：先文本/图片/自定义卡片。
4. 高级能力：撤回、已读、群设置、搜索、媒体缓存。

## 3. Push

iOS 当前是 APNs + Notification Center。RN 需要：

- iOS APNs token 注册。
- Android FCM 或国内渠道策略另行评估。
- Push payload 转 AppRoute。
- 前台通知和后台点击统一进入 route parser。

## 4. Universal Link / Share

复用当前 share link service：

```text
ShareLinkService
ShareLinkRepository
UniversalLinkRouter
```

RN 侧：

```text
services/share/shareLinkRepository.ts
navigation/linking.ts
```

## 5. Media

能力：

- 选择图片/视频。
- 拍照/录像。
- 压缩。
- 上传。
- 预览。
- 清理 temp file。

聊天媒体、发帖媒体、头像上传不要各写一套。

## 6. Location

用于小队线下活动：

```text
Features/Squads/SquadOfflineActivityLocationUploader.swift
```

RN 侧分期：

1. 前台定位。
2. 权限状态展示。
3. 上传当前位置。
4. 后台定位和电量优化后置。

## 7. Widget

当前 iOS 有倒计时 Widget。

RN 侧不建议首期做 Widget。后续用原生 target 继续实现，RN 只负责写入 shared storage 或调用 native module 同步 widget data。

## 8. 验收

- Native module 有 JS facade。
- JS 不直接散落调用原生 SDK。
- 权限拒绝、受限、永久拒绝都有 UI 状态。
- Push/deep link/share 进入同一套路由。
- IM SDK 初始化失败不影响非 IM 功能启动。

