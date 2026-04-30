# 工程师 3 交接文档：iOS A（App 壳层 / 登录 / Feed / 用户关系 / 小队）

> 角色定位：主客户端稳定器  
> 你的职责是把 iOS 主客户端最常用、最高频的日常链路做稳

---

## 1. 你要负责什么

你负责的是用户“每天打开 App 就会接触到”的部分：

1. App shell
2. 启动与会话恢复
3. 登录 / 注册 / 短信登录
4. feed 首页
5. 搜索
6. profile
7. follow graph
8. squad 基础页
9. 通用状态流转

简单说：

> 你负责的是 Raver iOS 的主使用路径，不是最炫的功能，但它决定这个 App 是否“日常可用”。

---

## 2. 你先应该怎么理解当前 App

当前 iOS App 是主客户端，不是演示壳。

它已经有：

1. App shell
2. Coordinator / router 思路
3. 登录态切换
4. feed / profile / squads / search / notifications / messages 等 feature 目录
5. `SocialService` / `WebFeatureService` 这样的服务层

但它还处于“主线已经成型，但仍需系统化收口”的阶段。

你进入后的任务不是推翻，而是：

1. 理解现有主线
2. 收口状态管理
3. 让日常主路径变稳
4. 让和后端 BFF 的协作更清晰

---

## 3. 你当前拥有的模块边界

### 3.1 App 壳层与启动

你要拥有：

1. app bootstrap
2. 登录态切换
3. AppCoordinator / router 逻辑
4. 会话恢复
5. session expired 后的回退体验

关键代码：

- [mobile/ios/RaverMVP/RaverMVP/Application](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application)
- [mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift)

### 3.2 登录与身份主路径

你要拥有：

1. 登录
2. 注册
3. 短信验证码
4. 恢复会话
5. 登出

关键代码：

- [mobile/ios/RaverMVP/RaverMVP/Features/Auth](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Auth)
- [mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift)
- [mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift)

### 3.3 Feed / 搜索 / 用户关系

你要拥有：

1. feed 首页与分页
2. search
3. post detail 基础跳转
4. 用户主页
5. 关注 / 取消关注
6. followers / following / friends
7. 我的 likes / reposts / saves

关键目录：

- [mobile/ios/RaverMVP/RaverMVP/Features/Feed](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed)
- [mobile/ios/RaverMVP/RaverMVP/Features/Search](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Search)
- [mobile/ios/RaverMVP/RaverMVP/Features/Profile](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile)

### 3.4 Squad 基础页

你要拥有：

1. recommended squads
2. my squads
3. squad profile 基础信息
4. join / leave / disband 入口的基础体验

关键目录：

- [mobile/ios/RaverMVP/RaverMVP/Features/Squads](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Squads)

---

## 4. 你重点要解决的问题

### 4.1 App 壳层一致性

你要明确：

1. 当前导航主线是什么
2. 哪些页面应该走统一路由
3. 登录态与未登录态怎么切换最稳
4. session expired 触发时 UI 如何统一回收

### 4.2 状态管理是否继续收口

你要快速判断：

1. `AppState` 当前承担了多少职责
2. 哪些状态已经太重
3. 哪些应该继续下沉到 feature 层
4. 哪些应该继续保留在全局

### 4.3 Feed / Profile / Follow 的交互稳定性

你要让这些主路径具备：

1. 可预测的 loading / empty / error 状态
2. 刷新和分页行为稳定
3. 登录失效体验不突兀
4. 关注关系的 UI 更新一致

### 4.4 后端错误模型对齐

你要推动和后端 A 一起收口：

1. unauthorized 处理
2. envelope 风格
3. 分页风格
4. 错误文案与用户可感知行为

---

## 5. 你入场后的前 4 周建议目标

### 第 1 周

1. 跑通 iOS 工程
2. 理解 AppState、SocialService、LiveSocialService
3. 走一遍登录、feed、profile、search、squad 主路径
4. 记录当前最明显的状态管理和路由痛点

### 第 2 周

1. 画出壳层与 feature 的关系图
2. 梳理主路径依赖的 BFF 接口
3. 确认 auth / feed / profile / squad 的稳定性问题

### 第 3 周

1. 优先治理会话恢复和 session expired 行为
2. 优先治理 feed / profile 的状态一致性
3. 开始收口 follow graph 相关体验

### 第 4 周

1. 给出 iOS 主路径架构收口建议
2. 和后端 A 固化主链路接口协作方式
3. 明确哪些模块你继续持有，哪些交给 iOS B

---

## 6. 你暂时不应该成为主 owner 的地方

这些内容不是你早期的主战场：

1. Tencent IM 会话与消息底层
2. 音视频消息发送
3. 内容编辑器复杂交互
4. event / dj / set 的深度编辑发布链路
5. Android Flutter

---

## 7. 你重点合作的人

### 后端工程师 A

要高频对齐：

1. auth / refresh / logout
2. feed / profile / follow / squad
3. unauthorized / session expired 处理

### iOS 工程师 B

要对齐：

1. squad 详情页与聊天入口衔接
2. notification 打开后的路由行为
3. 内容详情页跳转和壳层集成

---

## 8. 你阅读代码的起点

建议从下面这些位置开始读：

1. [mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift)
2. [mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift)
3. [mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift)
4. [mobile/ios/RaverMVP/RaverMVP/Application](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application)
5. [mobile/ios/RaverMVP/RaverMVP/Features/Auth](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Auth)
6. [mobile/ios/RaverMVP/RaverMVP/Features/Feed](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Feed)
7. [mobile/ios/RaverMVP/RaverMVP/Features/Profile](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile)
8. [mobile/ios/RaverMVP/RaverMVP/Features/Search](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Search)
9. [mobile/ios/RaverMVP/RaverMVP/Features/Squads](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Squads)

