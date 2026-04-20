# 08. 测试、质量与发布

## 目标

建立 Android Flutter 复刻的质量门禁，避免页面复刻只靠肉眼验证。

## 测试分层

| 层级 | 覆盖 |
|---|---|
| Unit | DTO decode、repository conversion、usecase |
| Widget | card、form、empty/error/loading、navigation chrome |
| Golden | TabBar、详情 hero、dark/light、卡片 |
| Integration | 登录、Tab、详情、返回、发帖、消息 |
| Manual smoke | 真机权限、上传、视频、外链 |

## 必跑命令

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run -d emulator
flutter build appbundle --release
```

## 回归矩阵

首批：

- 登录 -> Discover。
- Discover -> EventDetail -> back。
- Discover -> DJDetail -> follow -> back。
- Discover -> SetDetail -> play video -> fullscreen -> back。
- Circle -> PostDetail -> comment。
- Messages -> Chat -> send。
- Profile -> My Checkins -> EventDetail。
- 401 token expired。
- light/dark 切换。
- zh/en 切换。

## 性能检查

工具：

- Flutter DevTools
- profile mode
- performance overlay
- app size analyzer

重点：

- 首页启动
- Discover pager
- Events/DJs/Sets 列表滚动
- Event/DJ/Set 详情首屏
- 图片密集页
- 视频播放页

## 发布准备

必须完成：

- applicationId `com.raver.android`
- targetSdk 至少 35
- release signing
- adaptive icon
- app name
- release HTTPS base URL
- privacy policy
- min permissions
- Proguard/R8 默认策略验证

## 验收标准

- 每个完成页面都有对应 parity checklist 状态。
- 新增 DTO 有 fixture decode test。
- 新增页面至少有 widget smoke。
- 关键视觉组件有 golden。
- release bundle 能生成。

