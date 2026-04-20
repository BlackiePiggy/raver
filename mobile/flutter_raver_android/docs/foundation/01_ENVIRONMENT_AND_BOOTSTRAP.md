# 01. 环境与工程启动

## 目标

建立一个只承载 Android 的 Flutter 工程，放在 `mobile/flutter_raver_android/app/raver_android`，不影响现有 iOS 原生工程。

## 本机现状

- 当前仓库：`/Users/blackie/Projects/raver`
- 当前没有 `flutter` 命令
- 已准备脚本：`mobile/flutter_raver_android/scripts/bootstrap_flutter_project.sh`
- 后端默认 BFF：`http://localhost:8787`
- Android emulator 访问宿主机应使用：`http://10.0.2.2:8787`

## 安装步骤

1. 安装 Android Studio stable。
2. 安装 Flutter SDK stable。
3. 把 Flutter SDK 的 `bin` 加入 shell PATH。
4. 运行：

```bash
flutter doctor -v
flutter doctor --android-licenses
```

5. 创建 Android emulator，至少准备：

```text
Android 15 / API 35
Android 14 / API 34
Android 12 / API 31
```

6. 生成 Flutter 工程：

```bash
cd /Users/blackie/Projects/raver/mobile/flutter_raver_android
./scripts/bootstrap_flutter_project.sh
```

## 生成后的必要改造

1. 修改 Android applicationId 为 `com.raver.android`。
2. 设置 minSdk 23，targetSdk 至少 35。
3. 添加 debug network security config，允许本地 HTTP。
4. release 环境禁止明文 HTTP。
5. 增加 `--dart-define` 入口：

```bash
flutter run \
  --dart-define=RAVER_RUNTIME_MODE=live \
  --dart-define=RAVER_BFF_BASE_URL=http://10.0.2.2:8787
```

## 本地后端联调

```bash
cd /Users/blackie/Projects/raver
docker-compose up -d

cd /Users/blackie/Projects/raver/server
pnpm dev
```

如果是真机调试，把 base URL 改成 Mac 局域网 IP：

```text
http://<Mac-LAN-IP>:8787
```

## 验收标准

- `flutter doctor -v` 没有 Android 工具链关键错误。
- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter run -d emulator` 能打开空壳 App。
- App 能用 `10.0.2.2:8787` 访问本地 BFF health 或登录接口。

## 常见问题

- Android 模拟器不要用 `localhost` 访问 Mac 后端。
- 真机需要 Mac 与手机处于同一局域网，并确认防火墙未拦截 8787。
- Flutter SDK 不纳入仓库，工程只提交 Flutter app 源码与锁文件。

