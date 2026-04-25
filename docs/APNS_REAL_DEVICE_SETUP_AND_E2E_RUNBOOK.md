# APNs 真机配置与端到端验证手册（Raver）

> 适用项目：`/Users/blackie/Projects/raver`
>
> 目标：让任何同学都能从 0 到 1 完成 APNs 配置、真机 token 上报、服务端投递验证。
>
> 最后更新：2026-04-23（Asia/Kuala_Lumpur）

---

## 1. 先理解这条链路在做什么

APNs 成功的前提是 4 段都通：

1. iOS App 在真机拿到 device token（Apple 下发）
2. App 把 token 上报到你自己的服务端（Raver BFF / notification-center）
3. 服务端用 `.p8` 凭证调用 APNs
4. APNs 接收成功并按 token 投递到这台设备

任意一段断了，都会看到 `no-active-device-token` 或注册失败。

---

## 2. Apple Developer 后台配置（做一次）

### 2.1 App ID 开启 Push Notifications

位置：Apple Developer -> `Certificates, Identifiers & Profiles` -> `Identifiers` -> 选中你的 App ID（例如 `com.raver.mvp`）

要做的事：
- 打开 `Push Notifications` capability

目的：
- 让 provisioning profile 里带上 `aps-environment` entitlement，否则真机注册 APNs 会报：
  - `未找到应用程序的“aps-environment”的授权字符串`

说明：
- `Broadcast Capability` 不需要勾选（常规 APNs 不用它）。

### 2.2 创建 APNs Auth Key（.p8）

位置：Apple Developer -> `Keys` -> `+`

要做的事：
- 勾选 `Apple Push Notifications service (APNs)`
- 生成并下载 `.p8`（只能下载一次）

你需要记录 3 个值：
- `Key ID`（例如 `2NN4TU489W`）
- `Team ID`（开发者团队 ID）
- `Bundle ID`（例如 `com.raver.mvp`）

目的：
- 服务端通过 `Key ID + Team ID + .p8` 生成 JWT，作为 APNs provider 身份。

---

## 3. Xcode 工程配置（每个 target 要正确）

目标文件：iOS App target（RaverMVP 主 target）

### 3.1 Signing & Capabilities

必须确认：
- `Push Notifications` 已添加
- `Team` 正确
- `Bundle Identifier` 与服务端 `NOTIFICATION_APNS_BUNDLE_ID` 一致

如果你要收静默推送：
- 再加 `Background Modes` -> 勾选 `Remote notifications`

### 3.2 让新 entitlement 生效

当你刚打开 Push capability 后，建议顺序：

1. Xcode `Product -> Clean Build Folder`
2. 删除真机上旧 App
3. 重新 Run 安装

目的：
- 确保新 provisioning profile + entitlement 真正下发到设备。

---

## 4. 服务端 APNs 配置（server/.env）

在 `server/.env` 填下面这组（键名必须一致）：

```env
NOTIFICATION_APNS_ENABLED=true
NOTIFICATION_APNS_KEY_ID=<你的KeyID>
NOTIFICATION_APNS_TEAM_ID=<你的TeamID>
NOTIFICATION_APNS_BUNDLE_ID=com.raver.mvp
NOTIFICATION_APNS_PRIVATE_KEY_PATH=/Users/<you>/.secrets/apns/AuthKey_<KeyID>.p8
NOTIFICATION_APNS_USE_SANDBOX=true
```

说明：
- 私钥三选一即可：
  - `NOTIFICATION_APNS_PRIVATE_KEY_PATH`（推荐）
  - `NOTIFICATION_APNS_PRIVATE_KEY`
  - `NOTIFICATION_APNS_PRIVATE_KEY_BASE64`
- 本地 Xcode Debug 通常用 Sandbox：`NOTIFICATION_APNS_USE_SANDBOX=true`
- TestFlight/App Store 通常切到生产：`NOTIFICATION_APNS_USE_SANDBOX=false`

然后重启 server。

---

## 5. 真机连到你本地服务（关键）

你的场景是“真机连 Mac 热点”，这是可行的，内网 IP 没问题。

### 5.1 获取 Mac 局域网 IP

示例命令：

```bash
ipconfig getifaddr en0
```

### 5.2 iOS App 用 Live 模式 + 指向 Mac IP

必须满足：
- 真机运行（不是 simulator）
- `RAVER_USE_MOCK=0`
- `RAVER_BFF_BASE_URL=http://<Mac内网IP>:3901`
- iOS 系统通知权限已允许
- 登录用户是你要测的账号（例如 `uploadtester`）

目的：
- device token 要上报到你现在运行的这台本地 server，否则后台永远查不到 active token。

---

## 6. 一套可复现的端到端验证命令

### 6.1 先拿管理员 token

```bash
ADMIN_TOKEN=$(curl -sS -X POST http://localhost:3901/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"uploadtester","password":"123456"}' | jq -r '.token')
```

### 6.2 看 APNs 配置状态

```bash
curl -sS "http://localhost:3901/v1/notification-center/admin/status?windowHours=24" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.status.apns'
```

期望关键字段：
- `enabled: true`
- `configured: true`
- `providerHost` 与 `useSandbox` 匹配

### 6.3 发布测试通知（in_app + apns）

```bash
curl -sS -X POST http://localhost:3901/v1/notification-center/admin/publish-test \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "category":"major_news",
    "title":"APNs Smoke",
    "message":"hello from raver",
    "channels":["in_app","apns"],
    "targetUserIds":["1f4cafda-6d46-4dcf-8e98-7d4892d09425"]
  }' | jq .
```

成功期望：
- `results[].channel="apns"` 的 `success=true`
- 明细类似 `token_sent=1, token_failed=0`

### 6.4 查投递明细

```bash
curl -sS "http://localhost:3901/v1/notification-center/admin/deliveries?limit=20&userId=1f4cafda-6d46-4dcf-8e98-7d4892d09425" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.items'
```

成功期望：
- 同一个 `eventId` 下有：
  - `channel=in_app, status=sent`
  - `channel=apns, status=sent`

---

## 7. 你这次已经验证通过的回归用例（可长期复用）

1. 真机登录 `uploadtester`，发送 `publish-test` -> `apns=sent`
2. 真机登出 `uploadtester`，发送 `publish-test` -> `no-active-device-token`
3. 真机重新登录 `uploadtester`，再发 `publish-test` -> `apns=sent`

这个用例验证了：
- token 注册闭环正常
- 登出失活闭环正常
- 不会长期保留脏 token 造成串推

---

## 8. 常见报错对照表（快速定位）

### 8.1 `[Push] APNs register failed: 未找到 aps-environment`

原因：
- App 没有 Push entitlement 或 profile 没更新

处理：
1. Apple Developer 的 App ID 打开 Push Notifications
2. Xcode target 添加 Push Notifications capability
3. Clean + 卸载 App + 重新安装

### 8.2 `no-active-device-token`

原因高频项：
- 用了 simulator（不做真实 APNs）
- 真机没允许通知
- App 走了 mock 或错误 BFF 地址
- 登录用户不是目标 userId
- 刚登出后 token 已失活（这其实是正确表现）

### 8.3 `BadDeviceToken` / `DeviceTokenNotForTopic`

原因：
- `bundleId` 不匹配
- sandbox/prod 环境错配

处理：
- 核对 `NOTIFICATION_APNS_BUNDLE_ID`
- 本地 debug 用 `NOTIFICATION_APNS_USE_SANDBOX=true`

### 8.4 `InvalidProviderToken` / `MissingProviderToken`

原因：
- Key ID / Team ID / .p8 内容错误
- 私钥路径不可读

处理：
- 重新核对 `NOTIFICATION_APNS_KEY_ID` / `TEAM_ID`
- 检查 `.p8` 路径和读权限

---

## 9. 交接时最小检查清单

1. Apple 后台：App ID Push 开启 + `.p8` key 可用
2. Xcode：Push capability 已加，真机包含 `aps-environment`
3. `server/.env`：`NOTIFICATION_APNS_*` 配置完整
4. 真机：Live 模式 + 指向 Mac 内网 IP + 通知权限允许
5. `admin/status`：`enabled/configured=true`
6. `publish-test` + `deliveries`：APNs 为 `sent`

