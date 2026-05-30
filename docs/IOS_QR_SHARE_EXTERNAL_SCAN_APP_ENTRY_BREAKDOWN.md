# iOS 二维码分享与外部扫码进 App 任务拆解

## 1. 目标

把这条链路补完整：

1. 用户在 App 内点开“二维码分享”
2. App 生成可对外分享的二维码
3. 用户在 App 外使用系统相机、Safari、微信外浏览器等扫码
4. 已安装 App 时直接进入 Raver 对应页面
5. 未安装 App 时进入承接页，再引导去 App Store

这份文档只拆“当前还没闭环的执行项”，不重复完整分享系统设计。

关联文档：

- `docs/IOS_SHARE_SHORT_LINK_QR_SYSTEM_PLAN.md`
- `docs/IOS_SHARE_SHORT_LINK_QR_SYSTEM_EXECUTION_TRACKER.md`
- `docs/IOS_SHARE_SHORT_LINK_QR_SYSTEM_DEV_LOG.md`
- `docs/IOS_QR_SHARE_EXTERNAL_SCAN_DEPLOYMENT_RUNBOOK.md`

## 2. 当前现状

### 2.1 已有能力

- iOS 已注册 `raver://` scheme。
- iOS 已配置 Associated Domains：
  - `applinks:ravehub.top`
  - `applinks:www.ravehub.top`
- App 已有外部 URL 收口入口：
  - `mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/AppCoordinator.swift`
- App 已有 Universal Link 解析器：
  - `mobile/ios/RaverMVP/RaverMVP/Core/ShareLinkService.swift`
  - `UniversalLinkRouter.resolve(_:)`
- App 已有内部 deeplink 消费链路：
  - `AppState.systemDeepLinkEvent`
  - `MainTabCoordinatorView` 中的 `handleSystemDeepLink(...)`
- 分享短链接口模型已存在：
  - `/v1/share-links/resolve`
  - `/v1/share-links/{code}`
  - `/v1/share-links/{code}/events`

### 2.2 当前缺口

当前缺口不在“App 内路由”，而在“二维码对外落地链路”：

- 二维码必须统一编码 `https://.../s/{code}`，不能直接编码 `raver://...`
- 分享域名必须真实可访问，且 HTTPS 正常
- 分享域名必须部署 AASA
- `/s/{code}` 必须能完成短链解析、打开 App、未安装兜底
- 必须完成真机扫码验证

## 3. 核心结论

二维码里放的内容应统一为：

```text
https://ravehub.top/s/{code}
```

而不是：

```text
raver://event/123
```

原因：

- 系统相机、第三方扫码器首先识别的是 HTTPS
- iOS Universal Link 只对 HTTPS 域名生效
- 未安装 App 时，HTTPS 才有机会落到承接页或 App Store
- 统计扫码、打开、安装跳转等事件也需要先经过服务端链路

最终链路应为：

```text
App 内生成分享对象
-> 调用 /v1/share-links/resolve
-> 返回 shortUrl / qrCodeUrl / deepLink / fallbackUrl
-> 二维码展示 shortUrl
-> 外部扫码打开 https://ravehub.top/s/{code}
-> iOS 命中 Universal Link
-> AppCoordinator.onOpenURL 收到 URL
-> UniversalLinkRouter 解析成 raver://...
-> MainTabCoordinator 导航到目标页
```

## 4. 按模块拆解

## 4.1 后端分享服务

### 必做项

1. 保证 `/v1/share-links/resolve` 对所有二维码分享对象返回以下字段：
   - `shortUrl`
   - `canonicalUrl`
   - `deepLink`
   - `fallbackUrl`
   - `qrCodeUrl`
   - `posterUrl`

2. 明确二维码分享对象范围，至少覆盖：
   - `event`
   - `post`
   - `news`
   - `dj`
   - `set`
   - `label`
   - `festival`
   - `ranking_board`
   - `circle_id`
   - `rating_event`
   - `rating_unit`
   - `user_card`
   - `squad_card`

3. 保证 `shortUrl` 为外部可访问 HTTPS 链接：
   - 形式：`https://ravehub.top/s/{code}`

4. 新增或确认短链访问接口：
   - `GET /s/:code`

5. `GET /s/:code` 需要完成：
   - 校验 `code` 是否存在、是否可用
   - 找到对应 `deepLink`
   - 找到对应 `fallbackUrl`
   - 返回可用于 Universal Link 的承接响应

6. `GET /s/:code` 需要记录访问事件：
   - `open`
   - `redirect`
   - `app_open`
   - 可选：`scan`

### 输出要求

- 对同一个公开对象，重复生成二维码时应尽量复用稳定短链
- 私密邀请类对象才允许临时码、过期码、限次码
- 同一个 `code` 解析出的 `deepLink` 必须稳定

## 4.2 域名 / HTTPS / AASA / 承接页

### 必做项

1. 确认正式分享域名
   - 当前建议：`ravehub.top`
   - 如该域名暂时不可上线，则先换成真实可访问域名，不要停留在占位状态

2. 确认 HTTPS 可用
   - `https://ravehub.top/s/test`
   - `https://ravehub.top/.well-known/apple-app-site-association`

3. 部署 AASA 文件
   - 路径：`/.well-known/apple-app-site-association`
   - Content-Type：`application/json`
   - 不带 `.json` 后缀
   - 不重定向

4. AASA 至少覆盖这些路径：
   - `/s/*`
   - 如需要也可覆盖内容 canonical 路径：
     - `/e/*`
     - `/p/*`
     - `/n/*`
     - `/dj/*`
     - `/set/*`
     - `/label/*`
     - `/festival/*`

5. 实现最小承接页
   - 已安装 App：由 Universal Link 直接进 App
   - 未安装 App：显示“打开 Raver / 前往 App Store”
   - 链接失效：显示“链接已失效”
   - 链接被撤销：显示“内容不可用”

6. 承接页增加最小 OG Meta
   - `title`
   - `description`
   - `image`

### AASA 示例

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appIDs": ["TEAM_ID.com.raver.mvp"],
        "components": [
          { "/": "/s/*" },
          { "/": "/e/*" },
          { "/": "/p/*" }
        ]
      }
    ]
  }
}
```

备注：

- `TEAM_ID.com.raver.mvp` 需要替换成真实 Apple Team ID + Bundle ID
- 生产环境必须用真实值，不要把示例直接上线

## 4.3 iOS 客户端

### 已有基础

- `Info.plist` 已注册 `raver`
- `RaverMVP.entitlements` 已有 `applinks`
- `AppCoordinatorView.onOpenURL` 已做统一入口
- `UniversalLinkRouter` 已支持把 `/s/{code}` 解析成 app deeplink

### 需要确认和补齐

1. 所有“打开二维码”入口必须展示服务端返回的 `shortUrl` 对应二维码
   - 不允许前端直接把 `raver://...` 生成成二维码

2. 所有“复制链接”入口必须复制 `shortUrl`
   - 不允许复制 `deepLink`

3. 二维码详情页建议显示：
   - 二维码图片
   - 可复制的 HTTPS 短链
   - 当前分享对象标题
   - 加载失败提示

4. 补真机日志点，方便排查：
   - 收到的外部 URL
   - `UniversalLinkRouter.resolve(...)` 的解析结果
   - 最终消费的 `deeplink`

5. 核对 `allowedHosts`
   - 目前代码里是：
     - `ravehub.top`
     - `www.ravehub.top`
   - 如果正式分享域名变更，这里必须同步更新

6. 真机重新安装后验证一次 Universal Link 缓存行为
   - AASA 更新后，旧缓存可能影响结果

### 建议补充检查点

- `mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/AppCoordinator.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/ShareLinkService.swift`
- `mobile/ios/RaverMVP/RaverMVP/RaverMVP.entitlements`
- 各业务页面的 `open...QRCode(...)` 调用点

## 4.4 QA / 验收

### 真机必测

1. 系统相机扫码
   - 从相册中的二维码图扫码
   - 从第二台设备屏幕扫码

2. Safari 打开短链
   - 直接输入 `https://ravehub.top/s/{code}`

3. 已安装 App 场景
   - 能拉起 App
   - 能进入正确页面
   - 页面参数正确

4. 未安装 App 场景
   - 能进入承接页
   - 能点击去 App Store

5. 异常场景
   - 无效 `code`
   - 已撤销 `code`
   - 已过期 `code`
   - 分享对象已删除

6. 多对象回归
   - Event
   - Post
   - News
   - DJ
   - Set
   - User Card
   - Squad Card

### 验收标准

- 二维码图片可稳定显示
- 外部扫码不出现“无法识别”
- 已安装 App 时能直接进入对应页面
- 未安装 App 时有清晰兜底
- 无效链接有明确状态页
- 关键事件可在后端日志或埋点中看到

## 5. 推荐执行顺序

## Phase 1：服务端与域名闭环

1. 确认正式分享域名
2. 打通 `GET /s/:code`
3. 部署 HTTPS
4. 部署 AASA
5. 上线最小承接页

这是最关键阶段。没有这一层，二维码即使在 App 内能显示，外部扫码也不算完成。

## Phase 2：iOS 分享入口统一

1. 逐个核对二维码入口是否都走 `shortUrl`
2. 逐个核对复制链接是否都走 `shortUrl`
3. 补日志和错误提示

## Phase 3：真机联调与回归

1. 真机扫码验证
2. Safari 验证
3. 未安装场景验证
4. 异常码验证
5. 多内容类型回归

## 6. 分工建议

### 后端 / Web

- `share-links resolve` 出参兜底
- `/s/:code` 路由
- AASA
- HTTPS
- 承接页
- 埋点记录

### iOS

- 分享入口统一走 `shortUrl`
- 二维码页展示与错误处理
- Universal Link 真机验证
- 域名白名单同步

### QA / 产品

- 验证对象范围
- 验证安装 / 未安装 / 失效码场景
- 确认承接页文案和 App Store 跳转

## 7. Definition of Done

以下条件同时满足，才算“二维码分享 + 外部扫码进 App”完成：

- App 内任一支持对象都能生成二维码
- 二维码内容是 HTTPS 短链，不是自定义 scheme
- 分享域名 HTTPS 正常
- AASA 已部署且真机生效
- 已安装 App 时可从系统相机扫码直达目标页
- 未安装 App 时有承接页和 App Store 兜底
- 无效码、撤销码、过期码都有明确结果
- 关键打开事件可追踪

## 8. 一句话结论

这件事的最后一公里，不是继续写更多二维码 UI，而是把“二维码统一指向 HTTPS 短链 + 域名/AASA/承接页/真机验证”补齐。客户端主干已经在了，真正还没落地的是线上外部链路闭环。
