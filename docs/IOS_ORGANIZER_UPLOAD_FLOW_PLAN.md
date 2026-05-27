# iOS 主办方上传流程落地方案

## 使用说明

这份文档从现在开始作为 **主办方上传能力的唯一落地清单** 使用。

执行规则：

- 所有开发、联调、验收任务都在这里拆解。
- 每个任务都必须用 checkbox 维护状态。
- 每次实际执行完一项工作，都要同步更新本文件。
- 如果实现路径发生变化，优先更新本文件，再继续开发。

状态约定：

- `[ ]` 未开始
- `[x]` 已完成

## 进度总览

- [x] `2026-05-27` 已完成现状调研，确认“主办方上传”技术实体统一落到 `Brand / WikiFestival`
- [x] `2026-05-27` 已完成 event / DJ / brand 现有上传链路对比
- [x] `2026-05-27` 已完成首版产品与技术方案文档
- [x] 服务端 brand 创建/编辑 submission task 化
- [ ] 服务端 brand 图片草稿归属模型补齐
- [x] iOS `OrganizerUploadFlow` 基础框架落地
- [ ] iOS 草稿、图片、提交、成功态全链路打通
- [x] event 上传页接入“创建主办方”快捷流
- [ ] 联调、回归、真机验收完成

## 执行日志

### 2026-05-27

- [x] 梳理 iOS `EventUploadFlow`、`DJUploadFlow`、`LearnFestivalEditorView` 现状
- [x] 梳理服务端 `contentSubmission`、`brand`、`wikiFestival`、`upload-image` 现状
- [x] 盘点 `POST /v1/learn/festivals` 当前创建分支，确认普通用户创建已走 `submittedForReview`
- [x] 盘点 `PATCH /v1/learn/festivals/:id` 当前编辑分支，确认仍是同步直写 `wikiFestival`
- [x] 确认主办方上传不新建 `Organizer` 实体，而是复用 `brand`
- [x] 输出当前这份完整落地方案与实施 checklist
- [x] 为 brand patch submission 增加 `changeSummary` 生成能力
- [x] 新增 `content-submission-brand.service`，支持 brand create / edit canonical apply
- [x] worker 已支持 `brand` 自动处理与管理员 auto-approve 入库
- [x] `POST /v1/learn/festivals` 已统一改为 submission task，不再同步直写线上 brand
- [x] `PATCH /v1/learn/festivals/:id` 已对普通用户改为 submission task
- [x] 管理员 brand create / edit 已统一进入 async submission + worker auto-approve`
- [x] iOS `updateLearnFestival(...)` 已改为 `CreateContentResult<WebLearnFestival>`
- [x] iOS Learn Festival 编辑页已兼容 `.submittedForReview`
- [x] iOS `LearnModuleView` 已补齐遗漏的 `CreateContentResult` 兼容点
- [x] brand 图片上传已支持 `brandId / draftId` 双模式
- [x] brand 图片删除已支持 `brandId + urls` 与 `draftId + urls`
- [x] brand submission 已支持草稿图绑定到 `content-submission`
- [x] brand 审核通过已支持 submission 图片归属回绑到最终 `wiki_brand`
- [x] 服务端 `pnpm --dir server build` 已再次通过，确认本轮 brand 图片草稿改造无新增 TS 构建问题
- [x] iOS brand 图片 service / repository / mock 已对齐 `draftId` 上传与删除接口
- [x] iOS `xcodebuild -workspace ...` 已再次通过，确认本轮 brand 图片接口对齐无新增编译错误
- [x] iOS 构建方式已校正为使用 `.xcworkspace`，`SDWebImage` 缺失并非真实代码阻塞
- [x] iOS 已新建 `Features/Discover/Brands/UploadFlow/` 骨架目录与基础 Swift 文件组
- [x] iOS `OrganizerUploadFlow` 已具备本地 draft restore/save、step 切换、create/edit 标题与成功态占位
- [x] iOS `DiscoverRoute` 已新增 `organizerCreate / organizerEdit` 独立路由，并接入 `OrganizerUploadFlow`
- [x] Learn 页“新增主办方”与主办方详情“编辑”入口已切到新的 organizer 上传流
- [x] event 上传页主办方搜索为空时，已提供“直接创建这个主办方”的快捷入口，并会携带当前手填名称
- [x] iOS `OrganizerUploadFlow` 已补齐 create / edit 草稿 key、JSON 持久化、草稿恢复与继续/重开能力
- [x] iOS `OrganizerUploadFlow` 已补齐基础信息 / 品牌介绍 / 官方链接 / 关联活动的首版可编辑表单
- [x] iOS `OrganizerUploadFlow` 字段编辑已接入 debounce 草稿保存
- [x] 按用户要求，新的 iOS build 验证已暂缓，等待用户自行在空闲时执行
- [x] iOS `OrganizerUploadFlow` Step 1 已接入 avatar / background / proof / other 四类图片的真实上传、预览、删除与替换
- [x] iOS `OrganizerUploadFlow` 放弃草稿时已补齐未持久化 brand draft 图片的远端清理
- [x] iOS `OrganizerUploadFlow` 已接入 brand create / edit 的真实 payload mapper、审核提交流程与成功/失败文案
- [x] iOS `OrganizerUploadFlow` review 步骤已补齐主视觉预览、主要字段摘要、proof 摘要与审核确认区
- [x] event 上传页从“直接创建这个主办方”进入 organizer create 后，创建成功已可自动回填 `organizerFestivalID + organizerName`
- [x] organizer create 若进入审核中，event 上传页已保留手填主办方名并展示“审核通过后可绑定正式 ID”提示
- [x] event 详情页当前主办方品牌入口已确认继续使用 `festivalDetail`
- [x] iOS `OrganizerUploadFlow` Step 5 已改成 event 搜索绑定卡片，支持搜索、绑定、已绑列表展示与重复绑定防止
- [x] iOS `OrganizerUploadFlow` Step 6 已补齐“最终确认后再提交”链路，底部提交会先弹确认再发起真实 submit
- [x] 已修复 `OrganizerUploadMappers.imageAssets(from:)` 的 Swift 可空性推断编译错误，避免 `nil` 与 `WebEventImageAsset` 闭包返回类型冲突
- [x] iOS `OrganizerUploadFlow` 提交成功后已补齐草稿清理，当前 draft 恢复态、搜索态与本地缓存会一起重置
- [x] iOS `OrganizerUploadFlow` 成功态已统一改为“返回上一页”，不再跳转固定主办方页或我的发布页
- [x] iOS `OrganizerUploadFlow` review 步骤中的 `rights confirmation / identity confirmation` 勾选已接入真实 draft 状态保存
- [x] iOS `OrganizerUploadFlow` 单图上传失败已支持显式重试，avatar / background 失败后可重新选择图片重传
- [x] iOS `OrganizerUploadFlow` Step 3 已补齐最小简介长度校验，当前介绍少于 30 字会在步骤校验与页面提示中同步拦截
- [x] iOS `OrganizerUploadFlow` Step 3 已补齐多语言简介输入，当前 `descriptionI18n` 已接入 draft 持久化、review 展示与 create/edit payload 映射
- [x] 已再次核对服务端 `brand` submission / worker / 审核状态链路，补齐 Phase 1.3 / 1.4 中已实现但未勾选的文档项
- [x] 已按最新要求移除 iOS 旧主办方上传页面链路，`LearnModuleView` / 主办方详情仅保留新的 `OrganizerUploadFlow`
- [x] 主办方保存后的刷新通知已统一切到 `discoverOrganizerDidSave`，列表页与详情页均会回刷最新数据
- [x] 服务端 brand 图片上传已补齐 `sort / width / height / originalUrl / ownerType / ownerId` 返回，draft 与 persisted brand 两条链路字段统一
- [x] 服务端 brand submission 已增加图片资产标准化，proof 会被兜底标记为 `review_only`，avatar/background/poster/other 兜底标记为 `public`
- [x] 服务端 brand 创建/编辑提交成功时，已对当前 draft 下未被 submission 引用的草稿图做无主清理与 OSS 删除兜底
- [x] 已核对 brand `rejected / cancelled` 图片策略并与 event 对齐：`rejected` 保留 submission 图片，不回绑线上 brand，brand 当前无独立 `cancelled` 清图入口
- [x] 服务端图片上传已抽成统一 `10MB` 限制常量，brand 上传 `usage` 也已收口为 `avatar/background/poster/proof/other`
- [x] 服务端 brand 图片上传已增加同 owner + 同 usage + 同文件内容去重复用，避免重复上传生成多份草稿/线上资产
- [x] 服务端 brand 图片上传已区分公开图与 proof 图格式策略：公开图统一收口稳定格式，proof 保留审核清晰度并增加最短边 `1200px` 校验
- [x] 服务端 brand submission 已补齐 `revision` 并发保护，`wiki_festival.revision`、BFF 提交入口、submission create/resubmit 与 approve 入库链路现已统一校验 `baseBrandRevision`
- [x] 服务端 brand submission 已补齐主视觉必填、`official link / proof` 二选一、版权/主体声明必填校验，并把重复品牌初筛与 event 名称近似冲突预警写入 `reviewNotes.brandScreening`
- [x] iOS `OrganizerUploadFlow` 编辑草稿已接入 `brand.revision -> draft.baseBrandRevision -> UpdateLearnFestivalInput.baseBrandRevision` 透传，brand edit 并发冲突现已与 event 对齐

## 分阶段落地计划

### Phase 0 - 方案冻结与边界确认

目标：先把定义讲清楚，避免后面写到一半又改模型。

- [x] 确认“主办方上传”产品名成立，但技术实体统一使用 `brand / wikiFestival`
- [x] 确认以 `EventUploadFlow` 为最高标准，不沿用旧 `LearnFestivalEditorView` 做增量补丁
- [x] 确认创建和编辑都要纳入审核任务体系
- [x] 确认图片上传策略要补齐 `draftId`，不能继续只靠 `brandId`
- [x] 和后端最终确认 `entityType = brand` 的编辑提交流程改造范围
- [ ] 和 iOS 最终确认新目录、路由入口、旧页面保留策略
- [x] 和 iOS 最终确认新目录、路由入口、旧页面保留策略
- [ ] 和产品/运营最终确认主办方 proof 图片是否强制
- [ ] 和审核侧最终确认驳回 reason code 列表

验收标准：

- [ ] 所有参与方对实体归属、接口归属、审核口径无分歧
- [ ] 后续开发不再出现“要不要单独建 Organizer”反复讨论

### Phase 1 - 服务端任务化基础改造

目标：先把 brand 的提交链路改成和 event 一样的任务模式。

#### 1.1 brand submission 基础能力

- [x] 盘点 `POST /v1/learn/festivals` 当前创建分支与 `PATCH /v1/learn/festivals/:id` 当前编辑分支
- [x] 设计 `brand` create payload 标准结构
- [x] 设计 `brand` edit payload 标准结构
- [x] 设计 `brand` payload 中的 `changeSummary` 生成规则
- [x] 为 brand 编辑提交增加 `targetBrandId` / `editMode` 等 submission 字段
- [x] 确认 brand 是否需要 `revision` 字段以对齐 event 的并发保护
- [x] 若缺失 `revision`，补 schema 与迁移方案

##### 建议的 `brand` create submission payload

```json
{
  "entityType": "brand",
  "title": "Tomorrowland",
  "payload": {
    "name": "Tomorrowland",
    "nameI18n": {
      "zh": "明日世界",
      "en": "Tomorrowland",
      "ja": "トゥモローランド"
    },
    "abbreviation": "TML",
    "aliases": ["Tomorrow Land"],
    "country": "Belgium",
    "countryI18n": {
      "zh": "比利时",
      "en": "Belgium",
      "ja": "ベルギー"
    },
    "city": "Boom",
    "cityI18n": {
      "zh": "布姆",
      "en": "Boom",
      "ja": "ブーム"
    },
    "foundedYear": "2005",
    "frequency": "Annual",
    "frequencyI18n": {
      "zh": "每年",
      "en": "Annual",
      "ja": "毎年"
    },
    "tagline": "Live Today, Love Tomorrow, Unite Forever",
    "introduction": "Festival brand introduction...",
    "descriptionI18n": {
      "zh": "品牌介绍",
      "en": "Festival brand introduction",
      "ja": "ブランド紹介"
    },
    "organizerType": "festival_brand",
    "styleTags": ["EDM", "Festival", "Global"],
    "officialWebsite": "https://www.tomorrowland.com",
    "instagramUrl": "https://www.instagram.com/tomorrowland/",
    "facebookUrl": "",
    "twitterUrl": "",
    "youtubeUrl": "",
    "tiktokUrl": "",
    "links": [
      {
        "title": "Official",
        "icon": "globe",
        "url": "https://www.tomorrowland.com"
      }
    ],
    "boundEventIDs": [],
    "imageAssets": [
      {
        "type": "avatar",
        "url": "https://...",
        "fileName": "avatar.jpg",
        "mimeType": "image/jpeg",
        "sort": 0,
        "visibility": "public"
      },
      {
        "type": "proof",
        "url": "https://...",
        "fileName": "proof.jpg",
        "mimeType": "image/jpeg",
        "sort": 0,
        "visibility": "review_only"
      }
    ],
    "draftId": "organizer-upload-create-user-uuid",
    "rightsConfirmed": true,
    "identityConfirmed": true
  }
}
```

##### 建议的 `brand` edit submission payload

```json
{
  "entityType": "brand",
  "title": "Tomorrowland",
  "payload": {
    "isEditSubmission": true,
    "targetBrandId": "festival-tomorrowland",
    "baseBrandRevision": 12,
    "name": "Tomorrowland",
    "nameI18n": {
      "zh": "明日世界",
      "en": "Tomorrowland",
      "ja": "トゥモローランド"
    },
    "country": "Belgium",
    "city": "Boom",
    "foundedYear": "2005",
    "frequency": "Annual",
    "tagline": "Live Today, Love Tomorrow, Unite Forever",
    "introduction": "Updated introduction...",
    "descriptionI18n": {
      "zh": "更新后的品牌介绍",
      "en": "Updated introduction",
      "ja": "更新後の紹介"
    },
    "organizerType": "festival_brand",
    "styleTags": ["EDM", "Festival", "Global"],
    "officialWebsite": "https://www.tomorrowland.com",
    "instagramUrl": "https://www.instagram.com/tomorrowland/",
    "boundEventIDs": ["event-id-1", "event-id-2"],
    "imageAssets": [
      {
        "type": "background",
        "url": "https://...",
        "fileName": "bg.jpg",
        "mimeType": "image/jpeg",
        "sort": 0,
        "visibility": "public"
      }
    ],
    "draftId": "organizer-upload-edit-festival-tomorrowland-user-uuid",
    "rightsConfirmed": true,
    "identityConfirmed": true
  }
}
```

##### `changeSummary` 生成规则

- 统一在服务端提交入口生成，客户端不自己拼展示文案。
- create submission：
  - 固定总结为“新建主办方资料”
  - 若有 proof，附加“已提交证明材料”
  - 若有图片，附加“已提交主视觉素材”
- edit submission：
  - 按字段分组生成摘要，不逐字段机械罗列
  - 建议分组：
    - 基础信息
    - 品牌介绍
    - 官方链接
    - 图片素材
    - 关联活动
- 摘要优先输出中文，其次英文。
- `changeSummary` 同时保留结构化 diff 与最终展示文本。

##### 建议的 `changeSummary` 结构

```json
{
  "changeSummary": {
    "zh": "更新了品牌介绍、官方链接和背景图，补充了 2 个关联活动。",
    "en": "Updated profile, official links, background image, and added 2 related events."
  },
  "changeSummarySections": [
    {
      "key": "profile",
      "label": "品牌介绍",
      "changed": true
    },
    {
      "key": "links",
      "label": "官方链接",
      "changed": true
    },
    {
      "key": "images",
      "label": "图片素材",
      "changed": true
    },
    {
      "key": "events",
      "label": "关联活动",
      "changed": true,
      "addedCount": 2
    }
  ]
}
```

#### 1.2 brand 编辑改成 submission task

- [x] 将 `PATCH /v1/learn/festivals/:id` 从同步直写改为提交 `contentSubmission`
- [x] 普通用户编辑返回 `submittedForReview`
- [x] 管理员编辑改成 async auto-approve，而不是同步 bypass
- [x] brand 创建与编辑统一进入 worker
- [x] brand 提交进入 `My Publishes`
- [x] brand 提交进入通知中心审核盒子

#### 1.3 worker 支持 brand

- [x] 为 `contentSubmissionProcessingService` 增加 `brand` 类型处理
- [x] brand `processing -> reviewing` 状态流转落地
- [x] brand `reviewing -> approved` 入库逻辑落地
- [x] brand `processing -> failed` 错误处理落地
- [x] brand `reviewing -> rejected` 审核驳回逻辑复用并验证
- [x] 入库时写回 `createdEntityId`

#### 1.4 brand 审核校验

- [x] 增加名称必填校验
- [x] 增加主视觉图片必填校验
- [x] 增加 `official link` 或 `proof` 至少满足一项校验
- [x] 增加重复品牌初筛
- [x] 增加 event 名称近似冲突预警
- [x] 增加版权/主体声明字段校验

验收标准：

- [x] brand 创建提交后不再同步创建线上实体
- [x] brand 编辑提交后不再直接修改线上实体
- [x] `My Publishes` 能看到 brand 的 `处理中 / 审核中 / 已入库 / 未通过 / 处理失败`
- [x] worker 失败时用户可见，不会 silently fail

### Phase 2 - 服务端图片草稿归属模型

目标：让主办方图片和 event 一样可草稿化、可回收、可审核绑定。

#### 2.1 上传接口改造

- [x] 盘点 `/v1/wiki/brands/upload-image` 当前请求字段和返回字段
- [x] 给上传接口增加 `draftId`
- [x] 给上传接口增加 `usage`
- [x] 给上传接口增加 `sort`
- [x] 给返回值补齐 `ownerType` / `ownerId`
- [x] 给返回值补齐 `width` / `height`
- [x] 给返回值补齐 `originalUrl`

#### 2.2 删除与清理接口

- [x] 新增或改造 brand 上传图删除接口
- [x] 支持按 `draftId + urls` 删除
- [x] 支持按 `brandId + urls` 删除
- [x] 支持提交成功后清理无主草稿图
- [x] 支持放弃草稿时批量清理

#### 2.3 提交后绑定策略

- [x] brand submission payload 中纳入图片资产数组
- [x] 审核通过时把 draft 归属图片绑定到最终 brand
- [x] proof 类图片标记为“仅审核可见”
- [x] avatar/background/poster 标记为“可公开展示”
- [x] 校验 rejected / cancelled submission 是否要保留或清理图片

#### 2.4 图片处理约束

- [x] 统一图片大小限制
- [x] 统一图片格式转换策略
- [x] 统一 proof 图片清晰度保留策略
- [x] 统一失败重传与重复图处理策略

验收标准：

- [x] 创建 brand 前即可上传图片到 draft
- [x] 编辑 brand 时草稿图片不会污染线上实体
- [x] 放弃草稿后远端草稿图可清理
- [x] 审核通过后图片归属正确

### Phase 3 - iOS 上传流骨架

目标：先把 `OrganizerUploadFlow` 的壳子搭起来。

#### 3.1 目录与模型

- [x] 新建 `Features/Discover/Brands/UploadFlow/`
- [x] 新建 `OrganizerUploadFlowView.swift`
- [x] 新建 `OrganizerUploadFlowViewModel.swift`
- [x] 新建 `OrganizerUploadDraft.swift`
- [x] 新建 `OrganizerUploadStep.swift`
- [x] 新建 `OrganizerUploadValidation.swift`
- [x] 新建 `OrganizerUploadMappers.swift`
- [x] 新建 `OrganizerUploadDraftStore.swift`
- [x] 新建 `OrganizerUploadAnalytics.swift`

#### 3.2 基础 UI 容器

- [x] 搭建顶部步骤进度条
- [x] 搭建底部固定操作栏
- [x] 搭建 step 容器切换逻辑
- [x] 支持 create / edit 两种 mode
- [x] 支持从 `WebLearnFestival` hydrate 到 draft
- [x] 支持提交成功页替换编辑器内容

#### 3.3 路由与入口

- [x] 新建 create route
- [x] 新建 edit route
- [x] Learn 页新增“上传主办方”入口
- [x] 品牌详情页基于 `canEdit` 展示“编辑主办方”
- [x] event 上传页搜索为空时提供“创建主办方”

验收标准：

- [x] 可以从入口进入新的上传流
- [x] create / edit 两种模式路由正确
- [x] 旧 `LearnFestivalEditorView` 上传链路已移除，iOS 仅保留新的 `OrganizerUploadFlow`

### Phase 4 - iOS 草稿系统

目标：对齐 event 的本地草稿体验。

#### 4.1 草稿存储

- [x] 设计 create 草稿 key
- [x] 设计 edit 草稿 key
- [x] `Codable` 持久化 draft JSON
- [ ] 本地图片落盘到 sandbox 草稿目录
- [ ] 草稿 TTL 设为 14 天

#### 4.2 自动保存与恢复

- [x] 字段变化 debounce 保存
- [x] 退后台保存
- [x] 页面离开前保存
- [x] 新建页支持恢复上次草稿
- [x] 编辑页支持恢复该 brand 对应草稿
- [x] 支持“继续草稿 / 重新开始”

#### 4.3 放弃与清理

- [x] 离开时弹出“保存草稿 / 放弃草稿”
- [ ] 放弃草稿时删除本地图片
- [x] 放弃草稿时清理远端草稿图
- [x] 提交成功后清理对应草稿

验收标准：

- [ ] App 被切后台后草稿能恢复
- [ ] 新建和编辑草稿互不覆盖
- [ ] 放弃草稿后不会残留本地脏数据

### Phase 5 - iOS 分步表单实现

目标：按产品方案把 6 步 UI 全部落地。

#### 5.1 Step 1 媒体与主体证明

- [ ] 实现图片分区：`avatar / background / poster / proof / other`
- [x] 实现图片区卡片
- [ ] 实现选择、预览、删除、替换、重排
- [x] proof 区增加“仅审核可见”提示
- [x] 实现图片校验与错误提示

#### 5.2 Step 2 基础信息

- [x] 主办方名称输入
- [x] 多语言名称编辑
- [x] 别名编辑
- [x] 简称编辑
- [x] 国家 / 城市输入
- [x] 成立年份 / 频率 / tagline 输入
- [ ] 相似品牌搜索提醒卡

#### 5.3 Step 3 品牌介绍

- [x] 简介输入
- [x] 多语言简介输入
- [ ] 主办方类型选择
- [ ] 风格标签输入
- [x] 最小简介长度校验

#### 5.4 Step 4 官方链接与身份校验

- [x] 官网输入
- [x] 各社媒链接输入
- [ ] 额外链接列表编辑
- [x] rights confirmation 勾选
- [x] identity confirmation 勾选

#### 5.5 Step 5 关联活动与运营上下文

- [x] 活动搜索
- [x] 绑定已有 event
- [x] 展示已绑定活动列表
- [ ] 运营地区 / 品牌类型补充字段
- [x] 避免重复绑定

#### 5.6 Step 6 预览与提交

- [x] review 页总览
- [x] 主视觉图预览
- [x] 主要字段摘要
- [x] proof 摘要显示
- [x] 提交前最终确认

验收标准：

- [ ] 六步可完整走通
- [ ] 前后跳步状态正确
- [ ] 校验错误能定位到具体步骤

### Phase 6 - iOS 图片上传链路

目标：把图片上传体验做成 event 同级。

- [x] 提交图片前调用 `prepareAuthenticatedRequestForUserAction(source: ...)`
- [x] iOS 接口层已支持 brand 图片按 `draftId` 上传
- [x] 创建态图片按 `draftId` 上传
- [x] 编辑态未提交变更图片按 `draftId` 上传
- [ ] 已持久化图片标记 `persistedBrand`
- [x] 单图上传失败支持重试
- [x] 替换图片时清理旧草稿图
- [x] iOS 接口层已支持 brand 图片删除
- [x] 删除图片时同步更新 draft
- [x] 提交时把图片资产映射到 payload

验收标准：

- [ ] 所有图片都能在草稿期独立管理
- [ ] 图片上传失败不会破坏整个表单
- [ ] 提交后图片资产和页面展示一致

### Phase 7 - iOS 提交与成功态

目标：把提交结果、状态文案、成功页做完整。

#### 7.1 接口对齐

- [x] `createLearnFestival(...)` 继续使用 `CreateContentResult`
- [x] 将 `updateLearnFestival(...)` 改成 `CreateContentResult<WebLearnFestival>`
- [x] create / edit 两条链路都支持 `.created`
- [x] create / edit 两条链路都支持 `.submittedForReview`

#### 7.2 提交逻辑

- [x] 提交前调用 `prepareAuthenticatedRequestForUserAction(source: "organizer-upload-submit")`
- [x] create payload mapper 落地
- [x] edit payload mapper 落地
- [x] 提交失败文案落地
- [x] 提交成功页落地

#### 7.3 成功态

- [x] 直接创建成功页
- [x] 审核提交成功页
- [x] 成功后返回来源页（从哪儿进来就回到哪儿）
- [x] 清理草稿

验收标准：

- [x] create / edit 成功态行为一致
- [ ] 审核态文案与 event 保持一致
- [ ] 用户可以清楚知道后续去哪里看状态

### Phase 8 - event 上传页联动

目标：让主办方上传不成为孤岛。

- [x] event 上传页主办方搜索为空时展示“创建新主办方”
- [x] 创建成功后自动回填 `organizerFestivalID`
- [x] 如果 brand 处于审核中，允许 event 先保留手填主办方名
- [x] event 详情页品牌信息展示继续使用 `festivalDetail`
- [ ] brand 审核通过后可被 event 上传页搜索到

验收标准：

- [x] 用户不需要退出 event 上传页再手动去新建主办方
- [ ] brand 与 event 绑定链路自然流畅

### Phase 9 - 审核后台与运营配套

目标：让运营真的能审，不只是用户能提。

- [ ] brand 审核列表筛选验证
- [ ] proof 图片在审核端可见
- [ ] change summary 在审核端可见
- [ ] duplicate warning 在审核端可见
- [ ] 驳回 reason code 在审核端可选
- [ ] 审核通过后能正确入库到 `wikiFestival`

验收标准：

- [ ] 审核员可以根据材料独立完成审核
- [ ] 驳回理由能回到用户端

### Phase 10 - 测试与验收

目标：在上线前把主要路径走实。

#### 10.1 功能测试

- [ ] 新建主办方，无图片，校验拦截
- [ ] 新建主办方，只有 proof，无公开图，校验验证
- [ ] 新建主办方，完整成功提审
- [ ] 编辑主办方，提交审核
- [ ] 提交失败后保留草稿
- [ ] 草稿恢复正确
- [ ] 图片删除/替换正确

#### 10.2 状态链路测试

- [ ] `processing` 展示正确
- [ ] `reviewing` 展示正确
- [ ] `approved` 展示正确
- [ ] `rejected` 展示正确
- [ ] `failed` 展示正确

#### 10.3 联动测试

- [ ] `My Publishes` brand 项展示正确
- [ ] 通知中心内容审核消息展示正确
- [ ] event 上传页联动创建主办方正常
- [ ] 主办方详情页编辑后刷新结果正常

#### 10.4 真机回归

- [ ] iPhone 小屏布局验证
- [ ] iPhone 大屏布局验证
- [ ] 深色模式验证
- [ ] 图片权限拒绝后文案验证
- [ ] 弱网上传重试验证

验收标准：

- [ ] create / edit / draft / review / publish 五条主链路全部通过
- [ ] 无阻断级崩溃、卡死、状态错乱问题

## 当前执行顺序建议

为了避免返工，建议严格按这个顺序推进：

- [x] 先完成方案与 checklist
- [ ] 先做服务端 task 化，再做 iOS 提交页
- [ ] 先做服务端 `draftId` 图片归属，再做 iOS 图片草稿
- [ ] 先做 iOS 基础框架和草稿，再做复杂分步 UI
- [ ] 最后再接 event 上传页联动

## 本轮已完成

- [x] 已将文档升级为可执行实施清单
- [x] 已加入阶段化 checkbox 任务
- [x] 已加入执行日志区
- [x] 已约定后续每次执行完成后都回写本文件
- [x] 已把 brand create / edit 当前真实链路盘点结果回写到 checklist
- [x] 已把 brand submission service / worker / iOS 返回类型改造同步回 checklist
- [x] 已修正 iOS 构建结论为必须使用 `RaverMVP.xcworkspace`
- [x] 已记录 `LearnModuleView` 遗漏的 `CreateContentResult` 兼容修复
- [x] 已修正 backend build 结论为“当前阻塞来自既有脚本类型错误，非本次 brand 改造”
- [x] 已补齐 brand 草稿图上传 / 删除 / submission 绑定 / 审核通过回绑的后端闭环
- [x] 已用 `pnpm --dir server build` 重新验证本轮 brand 图片草稿改造可通过构建
- [x] 已补齐 iOS brand 图片上传 `draftId` / 删除接口的 service-repository-mock 底座
- [x] 已用 `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace ... build` 验证本轮 iOS 接口对齐可通过构建

## 背景与定位

当前 iOS 端已经具备两套比较完整的内容共建链路：

- `EventUploadFlow`：活动上传，已经覆盖多步骤 UI、本地草稿、图片分区、异步任务审核、`My Publishes` 状态回写。
- `DJUploadFlow`：DJ 上传，已基本对齐 event 的草稿恢复、图片上传、提交成功页、审核状态文案。

你这次要的“主办方上传”，如果严格按现有仓库的数据模型来落，不建议新造一个 `Organizer` 独立实体，而应该把“主办方”统一落到当前已经存在的 `Brand / WikiFestival` 线上。

原因：

- 活动侧已经支持 `organizerFestivalID` + `organizerName`，并通过品牌搜索绑定主办方。
- 服务端已经有 `entityType = brand` 的内容提交流程。
- iOS 端已经有 `LearnFestival` 的创建、编辑、详情、分享、图片上传能力。
- 通知中心、`My Publishes`、审核链路已经认识 `brand`。

所以本方案的核心结论是：

**“主办方上传” = 新建一套以 `Brand / WikiFestival` 为实体的 iOS 上传流，产品文案可以叫主办方，但技术落地统一按 brand 走。**

## 现状判断

### 已有能力

当前仓库里，Brand / WikiFestival 已经有这些基础能力：

- `POST /v1/learn/festivals` 支持创建，普通用户会返回 `submittedForReview`。
- `PATCH /v1/learn/festivals/:id` 支持编辑。
- `POST /v1/wiki/brands/upload-image` 支持图片上传。
- iOS `WebFeatureService.createLearnFestival(...)` 已经返回 `CreateContentResult<WebLearnFestival>`。
- iOS `LearnFestivalEditorView` 已能创建、编辑、上传头像和背景图。
- `My Publishes` 已支持 `brand` 类型展示。

### 当前不足

它距离 event 标准还差得很远，主要差在下面几件事：

1. 现在还是单页编辑器，不是 event 那种完整分步上传流。
2. 创建支持审核结果分支，但编辑仍是同步直写，不是 event 那种任务化编辑。
3. 图片上传只有 `brandId + usage`，没有 event 那种 `draftId`、临时归属、提交后绑定、放弃后清理。
4. 没有主办方上传专用的本地草稿体系。
5. 没有审核前机器处理、处理中/审核中/已入库/失败 的完整状态机对齐。
6. 没有对“主办方真实性”和“图片版权/主体归属”的专项审核字段。

所以这次不是简单改几个字段，而是要把主办方上传补成 event 同级能力。

## 目标

本方案目标是：

- 在 iOS 新建独立 `OrganizerUploadFlow`，不要继续在 `LearnFestivalEditorView` 上打补丁。
- UI、交互、草稿、审核、成功态都对齐 event 上传体验。
- 主办方实体统一落到 `brand`。
- 图片上传策略、提交策略、审核链路全部按 event 标准设计。
- 创建和编辑都走异步 submission task，不再让普通编辑直接写线上 `wikiFestival`。
- 上传完成后统一通过 `My Publishes` 和内容审核通知回看状态。

## 用户入口

建议保留三个入口：

1. `Discover -> Learn / Brand` 页新增 “上传主办方”
2. event 上传页主办方搜索为空时，提供 “创建新主办方”
3. 已有主办方详情页在 `canEdit == true` 时展示 “编辑主办方”

入口行为统一：

- 新建进入 `OrganizerUploadFlow(mode: .create)`
- 编辑进入 `OrganizerUploadFlow(mode: .edit(brand))`
- 编辑前必须重新拉最新实体，不能直接拿详情页快照进编辑器

## 推荐流程

按 event 的思路，建议把主办方上传拆成 6 步，而不是继续单页大表单。

### 1. 媒体与主体证明

目标：先解决“这是谁”和“图能不能用”。

字段与规则：

- 主视觉图片必填，以下至少一张：
  - `avatar/logo`
  - `poster/kv`
- 可选图片区：
  - `avatar`
  - `background`
  - `poster`
  - `proof`
  - `other`
- `proof` 强烈建议上传，作为人工审核的重要参考：
  - 官方主页截图
  - 官方社媒主页截图
  - 主办方营业/组织证明
  - 版权授权截图

UI 规则：

- 完全复用 event 第一页的图片卡片交互风格。
- 只允许相册选择，不接拍照。
- 支持预览、删除、替换、重排。
- `proof` 区单独显示“仅审核可见，不对外展示”。

### 2. 基础信息

必填字段：

- 主办方名称 `name`
- 国家 `country`
- 城市 `city`

建议字段：

- `nameI18n`
- `abbreviation`
- `aliases`
- `tagline`
- `foundedYear`
- `frequency`

设计原则：

- 多语言策略跟 event 一样：默认只编辑系统语言字段，其他语言折叠展开补充。
- 名称是主键式信息，必须做重名/近似重名提示。
- 如果搜索到现有主办方高度相似，优先提示“认领/补充”而不是重复创建。

### 3. 品牌介绍

目标：让这个主办方从“一个名字”变成“可读的品牌页”。

字段：

- `introduction`
- `descriptionI18n`
- 品牌标签 / 风格关键词
- 代表国家 / 城市
- 可选补充：品牌定位、历史、代表系列活动

校验：

- 简介建议最少 30 字。
- 不允许纯外链、纯广告文案、纯联系方式。

### 4. 官方链接与身份校验

目标：提升真实性评分，服务后续审核。

字段：

- `officialWebsite`
- `instagramUrl`
- `facebookUrl`
- `twitterUrl`
- `youtubeUrl`
- `tiktokUrl`
- 其他链接 `links`

审核策略：

- 至少需要一个官方链接或一张 `proof` 图片。
- 如果官方链接和名称明显不一致，进入人工审核加强队列。
- 链接页若能明显证明该主体是活动品牌/主办方，可降低人工核验成本。

### 5. 关联活动与运营上下文

这一页是主办方上传相对 DJ 上传新增的重点。

字段：

- 代表活动列表，可选绑定已有 event
- 运营地区
- 是否为活动品牌、巡演品牌、厂牌型主办方、俱乐部品牌
- 主办方别名 / 系列名

用途：

- 帮审核员判断这个 brand 是否是真实存在的活动主体
- 方便 event 上传页后续搜索和归并
- 避免用户创建一堆“活动名即主办方名”的碎片数据

### 6. 预览与提交

和 event 一样，最后必须有 review 页。

review 页内容：

- 主视觉图
- 主办方名称与别名
- 国家 / 城市 / 成立年份 / 频率
- 简介
- 官方链接
- 证明材料摘要
- 关联活动
- 提交说明与审核提示

提交前确认项：

- 我确认提交信息真实准确
- 我确认我有权上传这些图片
- 我理解审核未通过时需要补充材料后重提

## UI 结构建议

建议新建目录：

```text
mobile/ios/RaverMVP/RaverMVP/Features/Discover/Brands/UploadFlow/
  OrganizerUploadFlowView.swift
  OrganizerUploadFlowViewModel.swift
  OrganizerUploadDraft.swift
  OrganizerUploadStep.swift
  OrganizerUploadValidation.swift
  OrganizerUploadMappers.swift
  OrganizerUploadDraftStore.swift
  OrganizerUploadAnalytics.swift
  Components/
    OrganizerUploadProgressHeader.swift
    OrganizerUploadBottomBar.swift
    OrganizerUploadImageZoneCard.swift
    OrganizerUploadReviewSection.swift
    OrganizerUploadLinkField.swift
    OrganizerUploadDuplicateWarningCard.swift
```

设计约束：

- 不复用旧 `LearnFestivalEditorView` 当主流程。
- 可以复用其中已有的字段组件和图片选择逻辑，但流程容器必须独立。
- 新增和编辑都统一进 `OrganizerUploadFlowView`。

## 草稿模型

建议草稿结构按 event 方式单独建：

```text
OrganizerUploadDraft
  mode
    create
    edit(brandId)
  media
    images[]
      id
      zone: avatar | background | poster | proof | other
      localFileURL
      remoteURL
      ownership: pendingLocal | createDraftUploaded | editDraftUploaded | persistedBrand
      fileName
      mimeType
      sortOrder
  basic
    name
    nameI18n
    abbreviation
    aliases[]
    country
    countryI18n
    city
    cityI18n
    foundedYear
    frequency
    frequencyI18n
    tagline
  profile
    introduction
    descriptionI18n
    organizerType
    styleTags[]
  links
    officialWebsite
    instagramUrl
    facebookUrl
    twitterUrl
    youtubeUrl
    tiktokUrl
    extraLinks[]
  relations
    boundEventIDs[]
    boundEventTitles[]
  compliance
    rightsConfirmed
    identityConfirmed
  ui
    currentStep
    dirty
    uploadProgress
    validationErrors
```

本地草稿策略沿用 event：

- 使用 `Codable` 存 JSON。
- 图片本地缓存到 sandbox 草稿目录，不直接塞 JSON。
- 自动保存：
  - 字段变更 debounce 1 秒
  - 退后台
  - 页面离开前
- 草稿保留 14 天。
- 创建成功或任务提交成功后清理对应草稿。
- 重新进入新建页时询问“继续上次草稿 / 重新开始”。

## 图片上传策略

这部分必须严格按 event 标准来，不建议沿用当前 `brandId` 直传再回写的简单模式。

### 当前问题

当前 brand 图片上传是：

- 先创建主办方
- 拿到 `brandId`
- 再上传 avatar/background
- 再 patch 一次实体

这个模式有几个问题：

- 还没完成提交就先污染线上实体
- 无法支持创建前草稿图片管理
- 放弃草稿时无法可靠清理远端图片
- 审核驳回时图片归属和展示归属不清楚

### 目标策略

主办方图片上传改成和 event 同一套所有权模型：

- 上传时支持 `brandId` 或 `draftId`
- 创建态优先使用 `draftId`
- 编辑态未提交变更也优先使用 `draftId`
- 审核通过或自动入库时，再把图片从草稿归属绑定到最终 brand
- `rejected` 时保留 `content-submission` 归属图片，方便审核追溯、用户查看驳回材料与后续重提复用
- `cancelled` 当前沿用 event 语义理解为任务级/被新版本顶替状态，brand 现阶段没有独立取消入口，因此不额外做 submission 图片清理

### 建议接口

新增或改造：

- `POST /v1/wiki/brands/upload-image`
  - 入参增加 `draftId`
  - 入参增加 `usage`
  - 入参增加 `sort`
- `DELETE /v1/wiki/brands/uploaded-images`
  - 按 `draftId` / `brandId` + `urls` 清理

建议 `usage / zone`：

- `avatar`
- `background`
- `poster`
- `proof`
- `other`

返回字段建议与 event 对齐：

- `url`
- `originalUrl`
- `usage`
- `fileName`
- `mimeType`
- `width`
- `height`
- `ownerType`
- `ownerId`

### 上传约束

- 单图大小统一按服务端 `10MB` 限制执行
- `avatar/background/poster/other` 公开图上传时统一收口到稳定格式：
  - `webp` 原样保留
  - `png/jpeg` 服务端归一为 `jpeg`
- `proof` 图仅接受 `png/jpeg/webp`
- `proof` 图服务端增加最短边 `1200px` 校验，避免审核文字与主体信息不可读
- 失败图片支持单张重试
- 页面离开时不自动上传未确认图片

### 展示与审核分离

图片必须区分：

- 对外展示图：
  - `avatar`
  - `background`
  - `poster`
- 仅审核可见：
  - `proof`
  - 部分 `other`

这点很重要，否则审核材料会误出现在公开品牌页。

## 审核链路

审核链路必须完全按 event 的 submission task 标准落。

### 统一状态机

用户可见状态：

- `processing` -> `处理中`
- `reviewing` -> `审核中`
- `approved` -> `已入库`
- `rejected` -> `未通过`
- `failed` -> `处理失败`
- `cancelled` -> `已取消`

目标主链路：

`处理中 -> 审核中 -> 已入库`

失败分支：

`处理中 -> 处理失败`

`审核中 -> 未通过`

### 创建链路

1. iOS 冻结当前 `OrganizerUploadDraft`
2. 将 payload 提交为 `contentSubmission(entityType = brand)`
3. 服务端立即返回 submission，不同步创建 brand
4. worker 异步处理：
   - payload 校验
   - 图片资产校验
   - 链接合法性检查
   - 重复品牌检测
   - 证明材料检查
5. 通过机器处理后，状态进入 `reviewing`
6. 审核员通过后，正式写入 `wikiFestival`
7. 生成 `createdEntityId`
8. `My Publishes` 和通知中心回写状态

### 编辑链路

编辑必须和 event 一样 task 化，不要继续直写线上 brand。

目标流程：

1. 拉取最新 brand
2. hydrate 成 `OrganizerUploadDraft(mode: .edit)`
3. 用户修改内容
4. 提交后创建 brand edit submission task
5. 状态从 `processing -> reviewing -> approved`
6. 审核通过后再真正更新 `wikiFestival`

为什么必须这样做：

- 保证编辑也有审核历史
- 避免未审核图片立即覆盖线上品牌页
- 让 `My Publishes` 能统一追踪创建和编辑
- 和 event / DJ 的商业化内容治理口径一致

## 审核规则建议

### 机器预处理

自动处理阶段建议做这些检查：

- 名称是否为空
- 是否至少有一个官方链接或 proof
- 是否至少有一张主视觉图
- 图片 mime / 尺寸 / 体积是否合法
- 是否和已有 brand 高度重名
- 是否和已有 event 名称高度重名
- 外链域名是否异常
- 是否含明显垃圾词、灌水内容

### 人工审核关注点

人工审核建议重点看：

- 这是不是一个真实存在的主办方/活动品牌
- 名称和官方链接是否对应
- 图是不是官方图或至少合理可用
- 是否和现有品牌重复
- 是否应该合并到现有 brand 而不是新建
- 是否存在侵权、盗图、冒充官方主体

### 驳回原因模板

建议统一理由码，方便 iOS 展示和二次编辑：

- `duplicate_brand`
- `insufficient_proof`
- `invalid_official_link`
- `copyright_risk`
- `misleading_identity`
- `insufficient_profile`
- `image_quality_low`

用户文案要可读，例如：

- 疑似与已有主办方重复，请先搜索并补充现有词条
- 缺少足够的官方证明材料，请补充官网或官方社媒截图
- 图片存在版权风险，请更换为可使用的素材

## 提交成功态

提交后成功态必须和 event 一样，不直接 dismiss。

分两种：

### 1. 直接创建

适用于管理员或可自动入库场景。

文案：

- 主办方已创建
- 可前往详情页继续补充资料

动作：

- 查看主办方详情
- 返回上一页

### 2. 提交审核

普通用户默认走这条。

文案：

- 当前正在处理中，后续会通过通知更新为审核中或已入库
- 你可以在“我的发布”里查看状态

动作：

- 查看我的发布
- 返回品牌页

## 与 event 上传页的联动

这套主办方上传做好后，event 上传页要顺手升级两处：

### 1. 主办方搜索为空时支持新建

当前 event 上传页已经有：

- 主办方名称输入
- 搜索 `LearnFestival`
- 绑定 `organizerFestivalID`

下一步建议：

- 当搜索无结果时，行内提供“创建这个主办方”
- 创建成功后自动回填 `organizerFestivalID + organizerName`
- 如果是 submitted task，则保留手填主办方名，并标记“待主办方词条审核”

### 2. 主办方详情可反向看到活动

审核通过后的主办方详情页建议展示：

- 关联活动
- 最近更新
- 关注入口

这样 event 和 brand 才能形成可维护的内容图谱闭环。

## 服务端改造点

### 必做

1. `brand` 编辑提交改成 submission task 化
2. `brand` 图片上传支持 `draftId`
3. `brand` 图片删除支持按草稿归属清理
4. `brand` submission payload 增加图片资产、proof、rights confirmation
5. worker 增加 brand 类型处理逻辑
6. 审核通过时再落地 `wikiFestival`

### 建议做

1. 新增重复品牌检测服务
2. 新增主办方名称相似度预警
3. 在 brand 审核中记录 proof 与链接校验结果
4. 为 `brand` 增加 change summary，和 event / DJ 一样用于审核展示

## iOS 改造点

### 必做

1. 新建 `OrganizerUploadFlow`
2. 新建 `OrganizerUploadDraft` 与 `DraftStore`
3. 新建图片分区卡片与 review 页
4. 提交前调用 `prepareAuthenticatedRequestForUserAction(...)`
5. 创建与编辑都接入成功页
6. `My Publishes` 保持 `brand` 状态展示一致

### 必须补齐的接口差异

当前 iOS 还存在两处和 event 标准不一致：

1. `createLearnFestival(...)` 已支持 `CreateContentResult`
2. `updateLearnFestival(...)` 目前只返回 `WebLearnFestival`

要对齐 event，建议改成：

- `updateLearnFestival(...) -> CreateContentResult<WebLearnFestival>`

这样编辑也能返回：

- `.created(...)`
- `.submittedForReview(...)`

## 推荐实施顺序

### Phase 1

- 先出文档确定 brand 作为 organizer 实体
- 确定字段、图片区、审核规则

### Phase 2

- 服务端补 brand submission edit task
- 服务端补 brand draft image owner 模型

### Phase 3

- iOS 新建 `OrganizerUploadFlow`
- 接入草稿、本地图片、提交成功页

### Phase 4

- event 上传页接入“创建主办方”快捷链路
- `My Publishes` 和通知中心验证 brand 状态回写

### Phase 5

- 做真机走查：
  - 创建主办方
  - 编辑主办方
  - 图片上传失败重试
  - 草稿恢复
  - 审核中状态
  - 驳回后二次编辑重提

## 结论

如果你的要求是“完全仿照 event 的完整 UI、流程和原理”，那这次主办方上传不能继续停留在现在的 `LearnFestivalEditorView` 级别。

正确做法是：

- 产品名称叫“主办方上传”
- 技术实体统一落到 `Brand / WikiFestival`
- iOS 新建独立 `OrganizerUploadFlow`
- 图片、草稿、审核、状态回写全部按 `event` 标准实现
- 创建和编辑都统一纳入 submission task 体系

这样做完之后，主办方、活动、资讯、关注提醒、搜索绑定才会是一套真正闭环的内容系统。
