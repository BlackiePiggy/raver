# Raver iOS MVP (SwiftUI)

基于你确认的路线 B：`Mastodon (Feed) + Matrix (Chat) + 自建 BFF + SwiftUI 客户端`。

## 已实现的 MVP 范围

- 统一登录页（默认 Mock）
- 注册并自动登录
- 广场 Feed 列表
- 广场分页加载
- 动态发布（图文 URL 形式）
- 动态点赞
- 动态评论
- 关注/取消关注（作者按钮）
- 动态卡片一键进群（存在群组关联时）
- 消息页（私信/群聊分栏）
- 通知中心（关注/点赞/评论/群邀请）
- 新私信发起（输入用户名）
- 会话页（收发消息）
- 发现页（用户搜索 + 动态搜索）
- 发现页群组推荐
- 用户主页（关注 + 私信 + 用户动态列表）
- 群组主页（简介 + 成员 + 最新消息预览 + 加入并进入群聊）
- 个人主页与退出登录
- 统一服务层：`MockSocialService` + `LiveSocialService`

## 工程路径

- 工程目录：`/Users/blackie/Projects/raver/mobile/ios/RaverMVP`
- 项目文件：`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcodeproj`

## 启动步骤（本地）

1. 安装 Xcode（App Store，建议 15+）
2. 进入目录并生成工程

```bash
cd /Users/blackie/Projects/raver/mobile/ios/RaverMVP
xcodegen generate
```

3. 安装 iOS 依赖

```bash
pod install
```

4. 打开工程

如果已经执行了 `pod install`，优先打开 workspace：

```bash
open /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace
```

如果还没安装 CocoaPods，也可以先继续打开项目文件做纯 Swift 开发：

```bash
open /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcodeproj
```

5. Xcode 里选择模拟器（例如 `iPhone 16 Pro`）后点击 Run

## 如何查看效果

- 默认是 Mock 模式，直接运行即可看到完整流程
- 登录后可直接体验：广场 -> 点赞/评论 -> 发布 -> 消息 -> 聊天 -> 我的

## 切换到 Live 模式（对接你自己的 BFF）

在 Xcode Scheme 里配置环境变量：

- `RAVER_USE_MOCK=0`
- `RAVER_BFF_BASE_URL=http://你的BFF地址`

当前 Live 模式预留接口：

- `POST /v1/auth/login`
- `GET /v1/feed`
- `GET /v1/feed/posts/:id`
- `POST /v1/feed/posts`
- `POST|DELETE /v1/feed/posts/:id/like`
- `GET|POST /v1/feed/posts/:id/comments`
- `GET /v1/chat/conversations?type=direct|group`
- `GET|POST /v1/chat/conversations/:id/messages`
- `GET /v1/profile/me`
- `POST|DELETE /v1/social/users/:id/follow`
- `GET /v1/notifications`
- `GET /v1/openim/bootstrap`

## OpenIM iOS SDK

当前工程已预留 OpenIM iOS 登录骨架：

- 登录/注册成功后会请求 `/v1/openim/bootstrap`
- App 回到前台时会再次刷新 bootstrap
- 如果工程能 `import OpenIMSDK`，会自动执行 `initSDK + login`

如果本机还没安装 CocoaPods：

```bash
gem install ffi -v 1.15.5 --user-install --no-document
gem install zeitwerk -v 2.6.18 --user-install --no-document
gem install cocoapods -v 1.11.3 --user-install --no-document
export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH"
```

## 你接下来怎么开发（建议）

1. 先用 Mock 把 UI、交互和页面节奏定下来
2. 再落 BFF，把 Mastodon 和 Matrix 映射到统一接口
3. 最后把推荐、审核、通知中心加到 BFF 层
