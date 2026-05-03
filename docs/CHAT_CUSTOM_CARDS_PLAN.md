# Raver 聊天自定义卡片规划

## 目标

为 Raver 聊天系统建立一套统一的自定义分享卡片体系。  
所有卡片类型都应该：

- 在一个集中注册表中统一管理
- 拥有稳定的类型标识
- 拥有一致的数据契约
- 后续新增类型时不会破坏旧消息

这份文档是当前所有聊天自定义卡片的规划与进度跟踪主文档。

## 集中管理

App 侧统一注册表位置：

- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/CustomCards/ChatCustomCardRegistry.swift`

建议后续实现结构：

- `ChatCustomCardRegistry.swift`
  - 所有卡片类型
  - 推荐展示风格
  - 必填字段
  - 路由提示
  - 实现状态
- `ChatCustomCardPayload.swift`
  - 通用 payload 结构
- `ChatCustomCardRenderer.swift`
  - 按类型分发卡片渲染
- `ChatCustomCardViews/`
  - 各类卡片视图实现

## 通用数据契约

每种卡片都建议支持这些通用字段：

- `cardType`
- `entityID`
- `title`
- `subtitle`
- `coverImageURL`
- `badgeText`
- `primaryMeta`
- `secondaryMeta`
- `deeplinkRoute`
- `webFallbackURL`
- `shareContext`
- `version`

推荐的可选通用字段：

- `accentColorHex`
- `ctaText`
- `footerText`
- `avatarURL`
- `tagList`
- `startAt`
- `endAt`
- `scoreValue`
- `scoreScale`
- `authorName`
- `authorID`

## 展示风格分类

为了减少设计碎片，卡片应尽量复用少量视觉模板。

### 1. 封面信息卡

适用于：

- 活动
- DJ
- Festival
- Set
- 资讯
- Post
- 厂牌动态

布局建议：

- 左侧或顶部封面图
- 标题
- 副标题
- 1 到 3 行元信息
- 可选角标

### 2. 资料卡

适用于：

- 用户
- 投稿者
- 资讯作者
- 成员推荐

布局建议：

- 头像
- 标题
- 副标题
- 一行状态信息
- 可选关系或身份角标

### 3. 群组卡

适用于：

- 小队
- 小队邀请

布局建议：

- 群头像
- 标题
- 成员数 / 身份信息
- 可选角色角标
- 可选动作提示

### 4. 评分卡

适用于：

- Rating Unit
- Rating Event
- Score

布局建议：

- 标题
- 分数主体
- 分值范围 / 标签
- 可选上下文信息

### 5. 时间线卡

适用于：

- 活动时间表
- 演出时段
- 时间表
- Tracklist

布局建议：

- 标题
- 有序内容行
- 时间或序号标签
- 可选舞台 / 艺术家 / 曲目时长

### 6. 轻量链接卡

适用于：

- Label
- 风格
- 榜单
- ID

布局建议：

- 图标或小封面
- 标题
- 简短副标题
- 一行角标或元信息

### 7. 打卡卡

适用于：

- 我的打卡
- 一起打卡

布局建议：

- 地点或活动名
- 打卡时间
- 可选图片缩略图
- 可选人数信息

### 8. 社交片段卡

适用于：

- 评论
- 转发

布局建议：

- 小型作者信息区
- 引用片段
- 目标内容预览

## 卡片类型总表

说明：

- 每一种卡片都必须有对应的分享操作入口，否则即使渲染做完，也不能视为可交付。
- 下面这张总表里的“推荐分享入口”是当前默认建议，后续你可以继续改。

| 卡片类型 | 推荐展示风格 | 推荐分享入口 |
| --- | --- | --- |
| 活动 | 正方形封面卡（上方正方形图片，下方主题色信息区） | 活动详情页右上角分享；活动列表卡片更多菜单；活动日程页分享按钮 |
| 活动时间表 | 时间线卡 | 活动详情页 `Schedule` 标签内分享；活动时间表页右上角分享 |
| DJ | 正方形封面卡（上方正方形图片，下方主题色信息区） | DJ 详情页右上角分享；DJ 列表卡片更多菜单 |
| Set | 封面信息卡 | Set 详情页右上角分享；Set 列表卡片更多菜单 |
| 资讯 | 封面信息卡 | 资讯详情页右上角分享；资讯列表卡片更多菜单 |
| Post | 封面信息卡 | Feed 中每条 Post 的分享按钮；Post 详情页右上角分享 |
| Festival | 封面信息卡 | Festival 详情页右上角分享；Festival 列表卡片更多菜单 |
| Brand | 轻量链接卡 | Brand 详情页右上角分享；Brand 列表项更多菜单 |
| Label | 轻量链接卡 | Label 详情页右上角分享；Label 列表项更多菜单 |
| 音乐风格 | 轻量链接卡 | 风格详情页右上角分享；风格列表项更多菜单 |
| 榜单 | 轻量链接卡 | 榜单详情页右上角分享；榜单入口卡片更多菜单 |
| 用户 | 资料卡 | 用户主页右上角分享；头像长按菜单中的分享 |
| ID | 轻量链接卡 | ID 详情页右上角分享；ID 预览卡片更多菜单 |
| 投稿者 | 资料卡 | 投稿者主页右上角分享；投稿者列表项更多菜单 |
| 资讯作者 | 资料卡 | 作者页右上角分享；资讯详情页作者区分享按钮 |
| 成员推荐 | 资料卡 | 群成员页成员更多菜单；用户推荐列表项分享 |
| 小队 | 群组卡 | 小队主页右上角分享；小队卡片更多菜单 |
| 小队邀请 | 群组卡 | 小队邀请结果页；小队主页邀请完成页“分享给聊天” |
| Rating Unit | 评分卡 | Rating Unit 详情页右上角分享；评分结果卡片分享按钮 |
| Rating Event | 评分卡 | Rating Event 详情页右上角分享；活动评分结果页分享按钮 |
| Score | 评分卡 | 分数详情页分享按钮；评分完成结果页分享按钮 |
| 时间表 | 时间线卡 | 时间表详情页右上角分享；时间表模块更多菜单 |
| 演出时段 | 时间线卡 | 活动时间表单个 slot 更多菜单；Route DJ 提醒页分享按钮 |
| Tracklist | 时间线卡 | Tracklist 页右上角分享；Set 详情页内 Tracklist 模块分享按钮 |
| 我的打卡 | 打卡卡 | 我的打卡记录详情页分享按钮；打卡成功后分享入口 |
| 一起打卡 | 打卡卡 | 打卡完成页“邀请朋友一起打卡”；活动/场地页二级分享入口 |
| 评论 | 社交片段卡 | 评论长按菜单中的分享；评论详情页分享按钮 |
| 转发 | 社交片段卡 | 转发记录详情页分享；Post 转发后的结果页分享按钮 |
| 厂牌动态 | 封面信息卡 | 厂牌动态详情页分享；Brand 更新卡片更多菜单 |

### 核心内容卡片

1. 活动卡片
- 推荐风格：封面信息卡
- 关键字段：
  - `eventID`
  - `eventName`
  - `venueName`
  - `city`
  - `startAt`
  - `coverImageURL`
  - `eventType`

2. 活动时间表卡片
- 推荐风格：时间线卡
- 关键字段：
  - `eventID`
  - `eventName`
  - `scheduleSummary`
  - `stageName`
  - `startAt`
  - `endAt`

3. DJ 卡片
- 推荐风格：正方形封面卡（上方正方形图片，下方主题色信息区）
- 关键字段：
  - `djID`
  - `djName`
  - `coverImageURL`
  - `badgeText`
  - `country`
  - `genreText`

4. Set 卡片
- 推荐风格：封面信息卡
- 关键字段：
  - `setID`
  - `setTitle`
  - `djName`
  - `coverImageURL`
  - `durationText`
  - `relatedEventName`

5. 资讯卡片
- 推荐风格：封面信息卡
- 关键字段：
  - `articleID`
  - `headline`
  - `summary`
  - `coverImageURL`
  - `authorName`
  - `publishedAt`

6. Post 卡片
- 推荐风格：封面信息卡
- 关键字段：
  - `postID`
  - `authorName`
  - `contentPreview`
  - `firstMediaURL`
  - `likeCount`
  - `commentCount`

7. Festival 卡片
- 推荐风格：封面信息卡
- 关键字段：
  - `festivalID`
  - `festivalName`
  - `region`
  - `coverImageURL`
  - `seasonText`

8. Brand 卡片
- 推荐风格：轻量链接卡
- 关键字段：
  - `brandID`
  - `brandName`
  - `logoURL`
  - `region`
  - `summary`

9. Label 卡片
- 推荐风格：轻量链接卡
- 关键字段：
  - `labelID`
  - `labelName`
  - `logoURL`
  - `founderName`
  - `city`

10. 音乐风格卡片
- 推荐风格：轻量链接卡
- 关键字段：
  - `styleID`
  - `styleName`
  - `parentStyleName`
  - `summary`
  - `iconName` 或 `imageURL`

11. 榜单卡片
- 推荐风格：轻量链接卡
- 关键字段：
  - `boardID` 或 `boardKey`
  - `boardName`
  - `scopeText`
  - `coverImageURL`
  - `seasonText`

### 身份 / 社交卡片

12. 用户卡片
- 推荐风格：资料卡
- 关键字段：
  - `userID`
  - `displayName`
  - `avatarURL`
  - `username`
  - `bioPreview`

13. ID 卡片
- 推荐风格：轻量链接卡
- 关键字段：
  - `cardID`
  - `title`
  - `ownerName`
  - `avatarURL` 或 `artworkURL`
  - `shortDescription`

14. 投稿者卡片
- 推荐风格：资料卡
- 关键字段：
  - `contributorID`
  - `displayName`
  - `avatarURL`
  - `roleText`
  - `summary`

15. 资讯作者卡片
- 推荐风格：资料卡
- 关键字段：
  - `authorID`
  - `authorName`
  - `avatarURL`
  - `organization`
  - `summary`

16. 成员推荐卡片
- 推荐风格：资料卡
- 关键字段：
  - `userID`
  - `displayName`
  - `avatarURL`
  - `relationText`
  - `squadName`

### 群组 / 社区卡片

17. 小队卡片
- 推荐风格：群组卡
- 关键字段：
  - `squadID`
  - `squadName`
  - `avatarURL`
  - `memberCount`
  - `squadRole`
  - `summary`

18. 小队邀请卡片
- 推荐风格：群组卡
- 关键字段：
  - `squadID`
  - `squadName`
  - `avatarURL`
  - `inviterName`
  - `memberCount`
  - `inviteState`

### 评分卡片

19. Rating Unit 卡片
- 推荐风格：评分卡
- 关键字段：
  - `unitID`
  - `title`
  - `scoreValue`
  - `scoreScale`
  - `contextName`
  - `coverImageURL`

20. Rating Event 卡片
- 推荐风格：评分卡
- 关键字段：
  - `eventID`
  - `eventName`
  - `scoreValue`
  - `scoreScale`
  - `eventDate`
  - `coverImageURL`

21. Score 卡片
- 推荐风格：评分卡
- 关键字段：
  - `scoreID`
  - `title`
  - `scoreValue`
  - `scoreScale`
  - `sourceText`

### 时间 / 工具卡片

22. 时间表卡片
- 推荐风格：时间线卡
- 关键字段：
  - `timetableID`
  - `title`
  - `rows`
  - `dateText`
  - `placeText`

23. 演出时段卡片
- 推荐风格：时间线卡
- 关键字段：
  - `slotID`
  - `eventID`
  - `djID`
  - `djName`
  - `stageName`
  - `startAt`
  - `endAt`

24. Tracklist 卡片
- 推荐风格：时间线卡
- 关键字段：
  - `tracklistID`
  - `title`
  - `trackCount`
  - `firstTracksPreview`
  - `relatedSetName`

### 行为 / 打卡卡片

25. 我的打卡卡片
- 推荐风格：打卡卡
- 关键字段：
  - `checkinID`
  - `targetType`
  - `targetID`
  - `targetName`
  - `checkedInAt`
  - `coverImageURL`

26. 一起打卡卡片
- 推荐风格：打卡卡
- 关键字段：
  - `targetType`
  - `targetID`
  - `targetName`
  - `suggestedAt`
  - `coverImageURL`

### 社交片段卡片

27. 评论卡片
- 推荐风格：社交片段卡
- 关键字段：
  - `commentID`
  - `authorName`
  - `authorAvatarURL`
  - `bodyPreview`
  - `targetType`
  - `targetID`
  - `targetTitle`

28. 转发卡片
- 推荐风格：社交片段卡
- 关键字段：
  - `repostID`
  - `authorName`
  - `sourcePostID`
  - `repostTextPreview`
  - `targetTitle`

29. 厂牌动态卡片
- 推荐风格：封面信息卡
- 关键字段：
  - `brandID`
  - `brandName`
  - `updateType`
  - `coverImageURL`
  - `summary`
  - `publishedAt`

## 推荐的第一轮模板复用方式

为了控制实现成本，第一轮可以尽量复用统一模板。

- 封面信息模板：
  - 活动
  - DJ
  - Set
  - 资讯
  - Post
  - Festival
  - 厂牌动态
- 资料模板：
  - 用户
  - 投稿者
  - 资讯作者
  - 成员推荐
- 群组模板：
  - 小队
  - 小队邀请
- 评分模板：
  - Rating Unit
  - Rating Event
  - Score
- 时间线模板：
  - 活动时间表
  - 时间表
  - 演出时段
  - Tracklist
- 轻量链接模板：
  - ID
  - Label
  - Brand
  - 音乐风格
  - 榜单
- 打卡模板：
  - 我的打卡
  - 一起打卡
- 社交片段模板：
  - 评论
  - 转发

## 进度跟踪

状态说明：

- `未开始`
- `规划中`
- `协议设计`
- `渲染实现`
- `分享入口`
- `跳转联动`
- `已完成`

| 卡片类型 | 展示风格 | 推荐分享入口 | 协议 | 渲染 | 分享入口实现 | 跳转 | 总状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 活动 | 正方形封面卡（上方正方形图片，下方主题色信息区） | 活动详情页右上角分享；活动列表卡片更多菜单；活动日程页分享按钮 | 已有 Demo | 已有 Demo | 已接入（详情页） | 已接入 | 进行中 |
| 活动时间表 | 时间线卡 | 活动详情页 `Schedule` 标签内分享；活动时间表页右上角分享 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| DJ | 正方形封面卡（上方正方形图片，下方主题色信息区） | DJ 详情页右上角分享；DJ 列表卡片更多菜单 | 已有 Demo | 已有 Demo | 已接入（详情页） | 已接入 | 进行中 |
| Set | 封面信息卡 | Set 详情页右上角分享；Set 列表卡片更多菜单 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| 资讯 | 封面信息卡 | 资讯详情页右上角分享；资讯列表卡片更多菜单 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| Post | 封面信息卡 | Feed 中每条 Post 的分享按钮；Post 详情页右上角分享 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| Festival | 封面信息卡 | Festival 详情页右上角分享；Festival 列表卡片更多菜单 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| Brand | 轻量链接卡 | Brand 详情页右上角分享；Brand 列表项更多菜单 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| Label | 轻量链接卡 | Label 详情页右上角分享；Label 列表项更多菜单 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| 音乐风格 | 轻量链接卡 | 风格详情页右上角分享；风格列表项更多菜单 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| 榜单 | 轻量链接卡 | 榜单详情页右上角分享；榜单入口卡片更多菜单 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| 用户 | 资料卡 | 用户主页右上角分享；头像长按菜单中的分享 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| ID | 轻量链接卡 | ID 详情页右上角分享；ID 预览卡片更多菜单 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| 投稿者 | 资料卡 | 投稿者主页右上角分享；投稿者列表项更多菜单 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| 资讯作者 | 资料卡 | 作者页右上角分享；资讯详情页作者区分享按钮 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| 成员推荐 | 资料卡 | 群成员页成员更多菜单；用户推荐列表项分享 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| 小队 | 群组卡 | 小队主页右上角分享；小队卡片更多菜单 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| 小队邀请 | 群组卡 | 小队邀请结果页；小队主页邀请完成页“分享给聊天” | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| Rating Unit | 评分卡 | Rating Unit 详情页右上角分享；评分结果卡片分享按钮 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| Rating Event | 评分卡 | Rating Event 详情页右上角分享；活动评分结果页分享按钮 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| Score | 评分卡 | 分数详情页分享按钮；评分完成结果页分享按钮 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| 时间表 | 时间线卡 | 时间表详情页右上角分享；时间表模块更多菜单 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| 演出时段 | 时间线卡 | 活动时间表单个 slot 更多菜单；Route DJ 提醒页分享按钮 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| Tracklist | 时间线卡 | Tracklist 页右上角分享；Set 详情页内 Tracklist 模块分享按钮 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| 我的打卡 | 打卡卡 | 我的打卡记录详情页分享按钮；打卡成功后分享入口 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| 一起打卡 | 打卡卡 | 打卡完成页“邀请朋友一起打卡”；活动/场地页二级分享入口 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| 评论 | 社交片段卡 | 评论长按菜单中的分享；评论详情页分享按钮 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| 转发 | 社交片段卡 | 转发记录详情页分享；Post 转发后的结果页分享按钮 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |
| 厂牌动态 | 封面信息卡 | 厂牌动态详情页分享；Brand 更新卡片更多菜单 | 未开始 | 未开始 | 未开始 | 未开始 | 规划中 |

## 建议实施顺序

### 第一阶段

- 用户
- 小队
- 活动
- 活动时间表
- DJ
- Set
- Post
- 资讯

### 第二阶段

- Label
- Brand
- 音乐风格
- Festival
- 榜单
- Rating Unit
- Rating Event
- Tracklist

### 第三阶段

- 打卡类卡片
- 评论
- 转发
- 小队邀请
- 投稿者
- 资讯作者
- 成员推荐
- 厂牌动态
- 时间表
- 演出时段
- ID
- Score

## 未来扩展规则

后面新增卡片时，必须优先更新以下位置：

1. `ChatCustomCardRegistry.swift`
2. 本文档中的进度表
3. 通用 payload 协议
4. 路由解析器
5. 分享入口来源

不允许直接在聊天渲染代码里临时写死一种新卡片，而不先进入注册表体系。
