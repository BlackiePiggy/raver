# iOS 二维码外部扫码进 App 部署 Runbook

## 1. 目标

这份 runbook 用于把以下链路部署到真实环境：

1. App 内生成二维码
2. 二维码内容为 HTTPS 短链
3. 外部扫码打开分享域名
4. iOS 通过 Universal Link 进入 App
5. 未安装 App 时进入下载承接页

适用代码：

- `server/src/routes/share.routes.ts`
- `server/src/services/share-link.service.ts`
- `mobile/ios/RaverMVP/RaverMVP/RaverMVP.entitlements`

## 2. 必要环境变量

## 2.1 必填

这些变量建议在生产或测试部署环境中显式配置：

| 变量名 | 是否必填 | 说明 | 示例 |
|---|---|---|---|
| `PUBLIC_SHARE_BASE_URL` | 是 | 对外分享域名，所有短链 / 承接页 / AASA 基于它生成 | `https://ravehub.top` |
| `RAVER_IOS_ASSOCIATED_TEAM_ID` | 与 `RAVER_IOS_ASSOCIATED_APP_IDS` 二选一 | Apple Team ID，用于动态生成 AASA 的 `appIDs` | `ABCDE12345` |
| `RAVER_IOS_BUNDLE_ID` | 与 `RAVER_IOS_ASSOCIATED_TEAM_ID` 搭配使用 | iOS 主 App Bundle ID | `com.raver.mvp` |
| `RAVER_IOS_APP_STORE_URL` | 强烈建议 | 未安装 App 时跳转的 App Store 地址 | `https://apps.apple.com/app/id1234567890` |

## 2.2 二选一配置

### 方案 A：推荐，直接给完整 `appIDs`

```dotenv
RAVER_IOS_ASSOCIATED_APP_IDS=ABCDE12345.com.raver.mvp
```

适合：

- 你已经明确 Apple Team ID 和 Bundle ID
- 后续可能需要同时下发多个 `appIDs`

### 方案 B：由服务端拼接

```dotenv
RAVER_IOS_ASSOCIATED_TEAM_ID=ABCDE12345
RAVER_IOS_BUNDLE_ID=com.raver.mvp
```

服务端会自动生成：

```text
ABCDE12345.com.raver.mvp
```

## 2.3 可选

| 变量名 | 是否必填 | 说明 | 示例 |
|---|---|---|---|
| `RAVER_IOS_DOWNLOAD_URL` | 否 | `/s/:code/download` 的最终跳转地址；不配时默认回落到 `${PUBLIC_SHARE_BASE_URL}/download` | `https://ravehub.top/download` |
| `NOTIFICATION_APNS_TEAM_ID` | 否 | 如果没配 `RAVER_IOS_ASSOCIATED_TEAM_ID`，服务端会尝试复用这个值 | `ABCDE12345` |
| `SHARE_LINK_IP_HASH_SALT` | 否 | 分享页事件里的 IP hash salt | 高强度随机串 |

## 3. 推荐 `.env` 示例

可直接参考：

- [server/.env.share-links.example](/Users/blackie/Projects/raver/server/.env.share-links.example)

核心片段如下：

```dotenv
PUBLIC_SHARE_BASE_URL=https://ravehub.top

# 推荐直接配完整 appIDs
RAVER_IOS_ASSOCIATED_APP_IDS=ABCDE12345.com.raver.mvp

# 或者使用 Team ID + Bundle ID 组合
# RAVER_IOS_ASSOCIATED_TEAM_ID=ABCDE12345
# RAVER_IOS_BUNDLE_ID=com.raver.mvp

RAVER_IOS_APP_STORE_URL=https://apps.apple.com/app/id1234567890

# 可选；不配时默认使用 ${PUBLIC_SHARE_BASE_URL}/download
RAVER_IOS_DOWNLOAD_URL=https://ravehub.top/download

# 可选
SHARE_LINK_IP_HASH_SALT=replace-with-a-long-random-string
```

## 4. 上线前准备

## 4.1 域名

确认分享域名真实可访问，例如：

- `https://ravehub.top`
- `https://www.ravehub.top`

要求：

- HTTPS 正常
- 证书有效
- 对外网可访问

## 4.2 iOS App 配置

确认 iOS 主 App 已包含对应 Associated Domains：

- `applinks:ravehub.top`
- `applinks:www.ravehub.top`

当前代码位置：

- [RaverMVP.entitlements](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/RaverMVP.entitlements:13)

如果正式域名不是 `ravehub.top`，必须同步修改 iOS entitlement 并重新发包。

## 4.3 服务端代码

确认已部署包含以下路由的版本：

- `GET /.well-known/apple-app-site-association`
- `GET /apple-app-site-association`
- `GET /download`
- `GET /s/:code`
- `GET /s/:code/open`
- `GET /s/:code/download`

代码位置：

- [share.routes.ts](/Users/blackie/Projects/raver/server/src/routes/share.routes.ts:15)

## 5. 部署步骤

1. 在服务器或容器环境配置 `.env` / secrets：
   - `PUBLIC_SHARE_BASE_URL`
   - `RAVER_IOS_ASSOCIATED_APP_IDS` 或 `RAVER_IOS_ASSOCIATED_TEAM_ID + RAVER_IOS_BUNDLE_ID`
   - `RAVER_IOS_APP_STORE_URL`

2. 重启后端服务。

3. 检查服务日志，确认没有环境缺失导致的启动异常。

4. 用浏览器或 `curl` 验证 AASA 和下载页。

5. 用真实 share code 验证短链承接页。

6. 用真机验证 Universal Link。

## 6. 上线检查步骤

## 6.1 AASA 检查

执行：

```bash
curl -i https://ravehub.top/.well-known/apple-app-site-association
```

预期：

- HTTP 状态为 `200`
- `Content-Type` 为 `application/json`
- 响应体包含：
  - `applinks`
  - `details`
  - `appIDs`
  - `/s/*`

如果返回 `503`，说明 `RAVER_IOS_ASSOCIATED_APP_IDS` 或 `RAVER_IOS_ASSOCIATED_TEAM_ID` 没配好。

## 6.2 下载页检查

执行：

```bash
curl -i https://ravehub.top/download
```

预期：

- HTTP 状态为 `200`
- 返回 HTML
- 页面包含“下载 Raver”文案
- 如果配置了 `RAVER_IOS_APP_STORE_URL`，页面中应包含 App Store 按钮

## 6.3 短链承接页检查

执行：

```bash
curl -i https://ravehub.top/s/<share-code>
```

预期：

- 有效码返回 `200`
- 页面包含分享标题 / 摘要 / “打开 Raver” / “下载 App”
- 无效码返回错误态页面

## 6.4 打开按钮检查

执行：

```bash
curl -i https://ravehub.top/s/<share-code>/open
```

预期：

- HTTP `302`
- `Location` 指向 `raver://...`，并追加 `shareCode=...`

## 6.5 下载按钮检查

执行：

```bash
curl -i https://ravehub.top/s/<share-code>/download
```

预期：

- HTTP `302`
- 跳到 `RAVER_IOS_DOWNLOAD_URL`
- 如果没配，则跳到 `${PUBLIC_SHARE_BASE_URL}/download`

## 7. 真机验证步骤

1. 安装带最新 Associated Domains 的 iOS 包。
2. 删除旧包后重新安装一次，避免 Universal Link 缓存干扰。
3. 用 Safari 打开：
   - `https://ravehub.top/s/<share-code>`
4. 点击“打开 Raver”。
5. 确认 App 被拉起并进入正确页面。
6. 用系统相机扫描二维码，再验证一次。

未安装场景：

1. 在没有安装 App 的 iPhone 上打开同一短链
2. 确认进入承接页
3. 点击下载按钮
4. 确认跳转 App Store

## 8. 常见问题排查

## 8.1 `/.well-known/apple-app-site-association` 返回 503

原因：

- 没配置 `RAVER_IOS_ASSOCIATED_APP_IDS`
- 也没配置 `RAVER_IOS_ASSOCIATED_TEAM_ID`

处理：

- 补任意一套配置
- 重启服务

## 8.2 AASA 是 200，但 App 不拉起

优先检查：

- iOS 包里的 Associated Domains 是否和线上域名一致
- 真机是否重装过 App
- 域名是否有跳转链
- AASA 是否真的命中 `/s/*`

## 8.3 点击下载按钮没有去 App Store

原因：

- `RAVER_IOS_APP_STORE_URL` 没配置
- `RAVER_IOS_DOWNLOAD_URL` 配错

处理：

- 优先配置 `RAVER_IOS_APP_STORE_URL`
- 检查 `GET /download` 页面按钮是否正确
- 检查 `GET /s/:code/download` 的 302 `Location`

## 8.4 外部扫码打开的是网页，不是 App

可能原因：

- AASA 未生效
- iOS entitlement 域名不一致
- 扫码器不支持直接 Universal Link 拉起，需要点页面按钮

这时先用 Safari 手动打开短链排查，不要只靠扫码器判断。

## 9. 上线完成标准

以下条件同时满足，才算这一块真的上线完成：

- AASA 接口返回 `200`
- AASA 内容包含真实 `appIDs`
- 下载页可访问
- 有效短链承接页可访问
- 真机 Safari 打开短链可进 App
- 真机系统相机扫码后可完成打开
- 未安装场景可到 App Store

## 10. 变更后同步项

如果后续变更以下任一项，必须同步检查这条链路：

- 分享域名
- iOS Bundle ID
- Apple Team ID
- App Store 链接
- `/s/:code` 路由规则
- AASA 路径白名单
