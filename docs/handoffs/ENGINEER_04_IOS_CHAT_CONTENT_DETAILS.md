# 工程师 4 交接文档：iOS B（聊天 / 推送 / 内容详情与复杂交互）

> 角色定位：高复杂度客户端链路 owner  
> 你的职责是把 Tencent IM、通知打开链路、内容详情与编辑发布这些复杂能力做稳

---

## 1. 你要负责什么

你负责的是 iOS 端最“技术难度高、跨系统协作多”的部分：

1. Tencent IM 客户端集成
2. conversations / messages
3. 文本、图片、视频、语音消息链路
4. badge / push open / notification routing
5. event / dj / set detail
6. editor / publish / import / upload 复杂交互
7. 与后端的媒体上传、内容详情 schema 对齐

简单说：

> 你负责的是“不是每天每页都写代码，但一旦出问题就会非常难修”的那部分客户端主链路。

---

## 2. 你先应该怎么理解当前 App

当前 iOS 聊天主线已经不是 OpenIM，而是 Tencent IM。

正确理解应该是：

1. App 登录业务 session
2. App 请求 Tencent IM bootstrap
3. App 登录 Tencent IM SDK
4. Conversations / messages 主要由 IM SDK 提供
5. Raver 后端负责业务映射、群同步、通知中心、unread 聚合

同时，你还会接触内容详情与编辑器，因为这两块普遍涉及：

1. 深链路
2. 大对象渲染
3. 多媒体
4. 上传
5. 复杂状态

---

## 3. 你当前拥有的模块边界

### 3.1 Tencent IM bootstrap 与 SDK 使用主链路

你要拥有：

1. bootstrap 拉取与刷新
2. SDK 初始化与登录
3. app active / resume 时的刷新策略
4. Tencent IM 不可用时的客户端降级体验

关键代码：

- [mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift)
- [mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift)
- [mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift)

### 3.2 会话与消息

你要拥有：

1. conversations list
2. history messages
3. read / muted / clear history
4. direct conversation start
5. 文本消息
6. 图片消息
7. 视频消息
8. 语音消息

关键目录：

- [mobile/ios/RaverMVP/RaverMVP/Features/Messages](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages)

### 3.3 推送、badge、通知打开链路

你要拥有：

1. device push token 注册
2. APNS 打开后的 App 路由
3. unread badge 刷新
4. notification inbox 与会话未读协同

相关代码入口：

- [mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift)
- [mobile/ios/RaverMVP/RaverMVP/Features/Notifications](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Notifications)

### 3.4 内容详情与编辑发布复杂交互

你要拥有：

1. event detail
2. dj detail
3. set detail
4. 内容编辑页与上传页
5. lineup import / image import / upload flow
6. 富对象详情页的多状态体验

关键代码：

- [mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureService.swift)
- [mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift)
- [mobile/ios/RaverMVP/RaverMVP/Features/Discover](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover)
- [mobile/ios/RaverMVP/RaverMVP/Features/Circle](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Circle)

---

## 4. 你最应该关注的架构问题

### 4.1 Tencent IM 集成的客户端边界

你需要尽早回答：

1. AppState 当前是否承担了过多 IM 责任
2. IM session / chat store / UI 层怎么分得更清楚
3. Tencent IM 不可用时，哪些页面怎样降级

### 4.2 会话、未读、badge 三者的一致性

你需要重点盯：

1. App 内 unread 展示
2. notification inbox unread
3. icon badge
4. 打开推送后的状态修正

### 4.3 媒体发送与媒体上传的复杂交互

你会同时面对两类媒体：

1. 聊天消息媒体
2. 内容编辑器上传媒体

这两条链路都很容易出问题，尤其是在：

1. 进度
2. 失败重试
3. 本地临时文件管理
4. 上传完成后的 UI 回写

### 4.4 内容详情页模型复杂度

event / dj / set 详情页对象很大，且和编辑链路耦合。

你需要帮助定义：

1. 详情页最小稳定渲染模型
2. 编辑器最小稳定输入模型
3. 哪些字段由客户端做兼容，哪些交给后端收口

---

## 5. 你入场后的前 4 周建议目标

### 第 1 周

1. 跑通 iOS 工程
2. 跑通 Tencent IM bootstrap 到会话列表
3. 走一遍聊天、通知、event/dj/set 详情主路径
4. 记录最危险的复杂状态点

### 第 2 周

1. 画出 IM 客户端架构图
2. 梳理 unread / badge / notification 的状态来源
3. 梳理内容详情页与编辑器依赖的 BFF 契约

### 第 3 周

1. 优先稳定聊天主链路
2. 优先稳定通知打开链路
3. 优先稳定媒体发送 / 上传体验

### 第 4 周

1. 给出 IM 客户端分层收口建议
2. 和后端 A 对齐 IM / unread / notification 协作边界
3. 和后端 B 对齐 detail / editor / upload schema 收口计划

---

## 6. 你暂时不应该分散精力的地方

这些内容不是你早期的主战场：

1. auth 页面的微交互
2. feed 首页日常列表行为
3. profile / follow 基础逻辑
4. Android Flutter 工程
5. Web 页面

---

## 7. 你重点合作的人

### 后端工程师 A

重点对齐：

1. Tencent IM bootstrap
2. squad / group 映射
3. notification-center
4. unread / push token / badge

### 后端工程师 B

重点对齐：

1. event / dj / set detail schema
2. editor / import / upload 契约
3. ratings / checkins / wiki detail 的表现数据

### iOS 工程师 A

重点对齐：

1. 壳层路由
2. 登录态与通知打开后的跳转
3. squad 基础页到聊天页的入口协作

---

## 8. 你阅读代码的起点

建议从下面这些位置开始读：

1. [mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift)
2. [mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift)
3. [mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift)
4. [mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureService.swift)
5. [mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift)
6. [mobile/ios/RaverMVP/RaverMVP/Features/Messages](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages)
7. [mobile/ios/RaverMVP/RaverMVP/Features/Notifications](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Notifications)
8. [mobile/ios/RaverMVP/RaverMVP/Features/Discover](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover)
9. [mobile/ios/RaverMVP/RaverMVP/Features/Circle](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Circle)

