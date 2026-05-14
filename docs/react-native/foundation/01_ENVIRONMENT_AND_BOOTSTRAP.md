# Foundation 01 - Environment And Bootstrap

## 1. 目标

建立一个可以长期承载 Raver App 的 React Native 工程，而不是临时 Demo。

建议目标路径：

```text
mobile/react_native_raver/app
```

首期目标：

- RN app 能启动。
- 能连接本地 BFF。
- 能切换 mock/live。
- 能保存 token。
- 能进入 Auth/MainTabs。
- 能在 iOS/Android 模拟器运行。

## 2. 工程创建选择

### 方案 A: Expo Dev Client

适合：

- 想保留 Expo 的开发效率。
- 接受后续使用 prebuild / config plugin 管理原生工程。
- 仍需要接入自定义 native module。

注意：

- 不使用 Expo Go 作为主线。
- Tencent IM、Widget、Push、播放器等必须以 Dev Client 或 prebuild 验证。

### 方案 B: React Native CLI

适合：

- 原生集成会很重。
- 团队能维护 iOS/Android 原生工程。
- Tencent IM、Push、Widget、Extension、原生播放器是近期重点。

对 Raver 来说，如果 RN 是长期主线，`RN CLI` 更稳；如果首期需要快速验证跨端可行性，`Expo Dev Client` 也可以。

## 3. 推荐依赖

```text
Core:
  react-native
  typescript
  react-navigation/native
  react-navigation/native-stack
  react-navigation/bottom-tabs
  react-native-screens
  react-native-safe-area-context
  react-native-gesture-handler
  react-native-reanimated

State / data:
  @tanstack/react-query
  zustand
  zod

Storage:
  react-native-mmkv
  react-native-keychain

UI / lists:
  @shopify/flash-list
  react-native-svg
  react-native-fast-image or expo-image equivalent

Forms:
  react-hook-form
  @hookform/resolvers

Native:
  react-native-image-picker
  react-native-permissions
  react-native-share
  react-native-device-info
  notifee or platform push wrapper

Quality:
  eslint
  prettier
  jest
  @testing-library/react-native
  detox or maestro
  sentry/react-native
```

## 4. 环境变量

和 iOS `AppConfig` 对齐：

```text
RAVER_RUNTIME_MODE=mock|live
RAVER_BFF_BASE_URL=http://localhost:8787
RAVER_TENCENT_IM_SDK_APP_ID=
RAVER_PUSH_ENV=development|production
RAVER_VIRTUAL_ASSETS_ENABLED=true
RAVER_REAL_NAME_ENFORCEMENT_ENABLED=false
```

Android 模拟器访问宿主机：

```text
http://10.0.2.2:8787
```

iOS 模拟器访问宿主机：

```text
http://localhost:8787
```

真机访问：

```text
http://<Mac LAN IP>:8787
```

## 5. 启动顺序

本地联调建议：

```bash
docker-compose up -d
cd server && pnpm install && pnpm prisma:generate && pnpm dev
cd web && pnpm install && pnpm dev
cd mobile/react_native_raver/app && pnpm install && pnpm ios
```

如果后端仍按当前文档使用 `start-all.sh`：

```bash
./start-all.sh
```

再启动 RN app。

## 6. 首次落地文件

```text
src/app/App.tsx
src/app/providers/AppProviders.tsx
src/app/config/env.ts
src/navigation/RootNavigator.tsx
src/navigation/AuthNavigator.tsx
src/navigation/MainTabs.tsx
src/services/http/client.ts
src/services/storage/secureStorage.ts
src/store/sessionStore.ts
src/shared/theme/tokens.ts
```

## 7. 验收

- iOS 模拟器能打开登录页。
- Android 模拟器能打开登录页。
- `RAVER_BFF_BASE_URL` 可切换。
- app 重启后能读取 runtime config。
- 关闭后端时显示统一错误态，不崩溃。
- 打开 React Native dev menu 和日志正常。

