# Entity Change Diff Domain Service Design

## 1. 背景与目标

当前项目里已经存在几条和“变更摘要”相关的链路：

- `server/src/services/content-submission-change-summary.service.ts`：根据提交 payload 猜测“更新名称 / 图片 / 链接”等摘要。
- `server/src/services/content-submission-processing.service.ts`、`server/src/services/content-submission-event.service.ts`：在审核、处理通知中读取 `payload.changeSummary`。
- `server/prisma/schema.prisma` 中的 `AdminAuditLog` 与 `NotificationAdminContentHistory`：可以保存后台审计和通知发布历史。
- `event`、`dj`、`brand` 的更新流程散落在 controller / BFF / content submission processing 中。

这套旧方案的问题是：它只知道“请求里传了什么”，不知道“数据库里原来是什么、最终变成了什么”。因此它只能生成粗粒度摘要，不能稳定回答：

- 这次活动到底改了哪些字段？
- DJ 的 genres 是新增了一个标签，还是只是数组顺序变化？
- 活动 timetable 是新增演出、删除演出，还是某个 DJ 的时间/舞台变了？
- Brand 详情哪些内容能安全推送给用户，哪些只能用于后台审计？

本方案目标是一步到位建设一个领域级统一服务：`Entity Change Diff Domain Service`。所有第一批实体更新流程都统一调用它，不再继续维护旧的 payload 猜测式 summary。

第一批实体范围：

- `event`
- `dj`
- `brand`，当前对应 Prisma `WikiFestival`

暂不支持：

- `djSet`
- `news`
- `post`
- `label`
- 其他未来实体

服务应具备以下能力：

- 修改前后基于业务快照比较，而不是直接 diff request payload。
- 支持多层级对象、数组、关联表结构。
- 支持无序集合、有序列表、按业务 key 匹配的对象列表。
- 产出结构化 diff、私有详细摘要、运营摘要、公开推送摘要。
- 用户推送中展示具体旧值/新值，但只展示被标记为 public-safe 的字段。
- 长期保存 `changesJson + summary + beforeHash + afterHash`，不默认保存完整 before/after snapshot。
- 替代旧的 `content-submission-change-summary.service.ts`。

## 2. 已确认产品决策

| 决策项 | 结论 |
| --- | --- |
| 文档落点 | `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` |
| 快照持久化 | 不长期保存完整 before/after snapshot；只保存 hash、结构化 changes 和摘要 |
| 用户推送 | 需要显示具体旧值/新值 |
| 敏感信息 | 用户推送只显示 public-safe 字段的旧值/新值；敏感字段只进入后台审计 |
| Event 阵容语义 | `lineupArtists` 按 artist identity 比较；`performances` 按 `identityKey` 比较；时间/舞台/日期变化算具体修改 |
| 第一批实体 | `event`、`dj`、`brand(WikiFestival)` |
| 旧服务策略 | 旧 payload 猜测式 summary 直接废弃，改为新服务统一生成 |

## 3. 总体架构

### 3.1 核心流程

```text
update request
  -> EntityChangeService.captureBefore(entityType, entityId)
  -> execute domain update in transaction/use case
  -> EntityChangeService.captureAfter(entityType, entityId)
  -> canonicalize snapshots
  -> hash tree compare
  -> recursive diff
  -> classify visibility/sensitivity
  -> generate private/operator/public summaries
  -> persist entity_change_logs
  -> bridge to admin_audit_logs / notification_admin_content_history / push metadata
  -> return updated entity + change result
```

### 3.2 模块边界

建议新增独立模块：

```text
server/src/modules/entity-change/
  index.ts
  entity-change.service.ts
  entity-change.types.ts
  entity-change.registry.ts
  entity-change.repository.ts
  entity-change-canonicalizer.ts
  entity-change-diff-engine.ts
  entity-change-summarizer.ts
  entity-change-visibility.ts
  snapshots/
    event.snapshot.ts
    dj.snapshot.ts
    brand.snapshot.ts
  configs/
    event.change-config.ts
    dj.change-config.ts
    brand.change-config.ts
```

职责划分：

| 文件 | 职责 |
| --- | --- |
| `entity-change.service.ts` | 对外 facade；提供 capture、diff、persist、withChangeTracking |
| `entity-change.registry.ts` | 注册每个实体的 snapshot builder 和 diff config |
| `entity-change.repository.ts` | 写入/查询 `entity_change_logs` |
| `entity-change-canonicalizer.ts` | 规范化对象、数组、日期、Decimal、null/empty |
| `entity-change-diff-engine.ts` | hash tree 与递归 diff |
| `entity-change-summarizer.ts` | 把结构化 changes 转换为中文/英文摘要 |
| `entity-change-visibility.ts` | 判断字段是否能进入用户推送 |
| `snapshots/*.snapshot.ts` | 每种实体如何读取业务快照 |
| `configs/*.change-config.ts` | 每种实体的 path 语义、标签、可见性、数组策略 |

## 4. 数据模型

### 4.1 新增表：`entity_change_logs`

长期保存结构化变更，不保存完整快照。

建议 Prisma model：

```prisma
model EntityChangeLog {
  id                    String   @id @default(uuid())
  entityType            String   @map("entity_type")
  entityId              String   @map("entity_id")
  operationType         String   @map("operation_type") // create, update, delete, system_sync
  actorId               String?  @map("actor_id")
  actorRole             String?  @map("actor_role")
  source                String?  // admin_api, bff_web, content_submission, system_job
  sourceRoute           String?  @map("source_route")
  requestId             String?  @map("request_id")

  snapshotSchemaVersion Int      @map("snapshot_schema_version")
  diffSchemaVersion     Int      @map("diff_schema_version")
  revisionBefore        Int?     @map("revision_before")
  revisionAfter         Int?     @map("revision_after")
  beforeHash            String?  @map("before_hash")
  afterHash             String?  @map("after_hash")

  changed               Boolean  @default(true)
  changeCount           Int      @default(0) @map("change_count")
  privateSummaryZh      String?  @map("private_summary_zh") @db.Text
  operatorSummaryZh     String?  @map("operator_summary_zh") @db.Text
  publicSummaryZh       String?  @map("public_summary_zh") @db.Text
  privateSummaryEn      String?  @map("private_summary_en") @db.Text
  operatorSummaryEn     String?  @map("operator_summary_en") @db.Text
  publicSummaryEn       String?  @map("public_summary_en") @db.Text

  changes               Json
  publicChanges         Json     @map("public_changes")
  metadata              Json?

  createdAt             DateTime @default(now()) @map("created_at")

  @@index([entityType, entityId, createdAt])
  @@index([actorId, createdAt])
  @@index([operationType, createdAt])
  @@index([changed, createdAt])
  @@map("entity_change_logs")
}
```

### 4.2 为什么不保存完整快照

不保存完整 before/after snapshot 的理由：

- Event、Brand、DJ 可能包含外链、图片、审核证明、source 数据、第三方平台数据。
- 完整快照会显著增加数据库体积。
- 一旦推送或审计系统误用完整快照，容易产生隐私泄露。
- 主要产品需求是“具体改了什么”，结构化 changes 已经足够。

如果未来需要回滚能力，可以新增短期归档表或对象存储压缩快照，不和第一版 change log 混在一起。

## 5. 核心类型设计

### 5.1 Snapshot

```ts
export type EntityType = 'event' | 'dj' | 'brand';

export type EntitySnapshot = {
  entityType: EntityType;
  entityId: string;
  displayName: string;
  revision: number | null;
  schemaVersion: number;
  capturedAt: string;
  data: Record<string, unknown>;
};
```

快照原则：

- `data` 只放业务字段。
- 不放 `updatedAt`、`createdAt`，除非某实体有明确业务展示需求。
- 不放一次请求的临时字段，例如 `clearXxx`、`editMode`、`baseBrandRevision`。
- JSON 字段必须展开成稳定结构。
- Decimal 转 string 或 number，但同一字段必须保持一致。
- Date 统一 ISO 8601。

### 5.2 Change

```ts
export type ChangeKind =
  | 'added'
  | 'removed'
  | 'updated'
  | 'reordered'
  | 'unchanged';

export type ChangeAudience = 'private' | 'operator' | 'public';

export type EntityChange = {
  id: string;
  kind: ChangeKind;
  path: string;
  pathLabelZh: string;
  pathLabelEn: string;
  category: string;
  audience: ChangeAudience;
  publicSafe: boolean;
  sensitive: boolean;
  before: unknown;
  after: unknown;
  beforeDisplayZh: string | null;
  afterDisplayZh: string | null;
  beforeDisplayEn: string | null;
  afterDisplayEn: string | null;
  itemKey?: string | null;
  itemLabelZh?: string | null;
  itemLabelEn?: string | null;
  children?: EntityChange[];
};
```

用户推送需要旧值/新值，因此 public-safe change 必须带 `beforeDisplayZh` 与 `afterDisplayZh`。

示例：

```json
{
  "kind": "updated",
  "path": "location.venueName",
  "pathLabelZh": "场地名称",
  "category": "location",
  "audience": "public",
  "publicSafe": true,
  "sensitive": false,
  "before": "Club A",
  "after": "Club B",
  "beforeDisplayZh": "Club A",
  "afterDisplayZh": "Club B"
}
```

## 6. Canonicalization 规则

### 6.1 统一规则

| 数据类型 | 规范化规则 |
| --- | --- |
| object | key 字典序排序 |
| string | 默认 trim；连续空白压缩为单空格；URL 保留原大小写但比较 key 可小写 |
| empty string | 按字段配置决定等同 null 还是保留 |
| Date | ISO string |
| Decimal | string，避免浮点误差 |
| number | 保持 number |
| boolean | 保持 boolean |
| null / undefined | undefined 不进入快照；可清空字段用 null |
| i18n JSON | 固定 key 顺序：`zh`, `en`, `ja` |

### 6.2 数组策略

不能一刀切排序数组。每个 path 必须在 config 中声明数组语义。

```ts
export type ArrayDiffStrategy =
  | { type: 'set'; itemIdentity?: 'value' | 'hash'; sort?: true }
  | { type: 'ordered-list'; itemIdentity?: 'index' | 'key' }
  | { type: 'keyed-list'; keyPath: string; orderMatters: boolean };
```

| 策略 | 含义 | 例子 |
| --- | --- | --- |
| `set` | 顺序不代表业务变化 | DJ genres、aliases、Brand aliases、referenceLinks |
| `ordered-list` | 顺序本身有意义 | ticket tiers、stage order |
| `keyed-list` | 按业务 key 匹配对象，再比较对象内部字段 | Event performances、lineup artists、brand links |

### 6.3 Hash Tree

hash tree 用于快速判断子树是否相同，并保证“等价结构”不会产生噪音 diff。

```ts
type HashNode = {
  path: string;
  hash: string;
  value?: unknown;
  children?: HashNode[];
};
```

比较逻辑：

```text
if beforeRootHash === afterRootHash:
  return []

for each child path:
  if childHashBefore === childHashAfter:
    skip
  else:
    recurse
```

注意：hash 只用于判断相等与剪枝；最终用户可见结果必须来自结构化 diff，不能只返回 hash 差异。

## 7. Diff Engine 规则

### 7.1 标量字段

标量字段比较规范化后的值：

```text
before === after -> no change
before missing, after exists -> added
before exists, after missing/null -> removed
otherwise -> updated
```

### 7.2 Set 数组

Set 数组输出新增/删除，不输出纯顺序变化。

示例：

```json
{
  "path": "profile.genres",
  "kind": "added",
  "itemLabelZh": "Hard Techno",
  "beforeDisplayZh": null,
  "afterDisplayZh": "Hard Techno"
}
```

### 7.3 Ordered List

Ordered list 需要区分：

- item 内容变了。
- item 新增/删除。
- 仅排序变了。

如果 `orderMatters = true`，重排输出 `reordered`。

### 7.4 Keyed List

Keyed list 按业务 key 做三步：

```text
before keys - after keys -> removed
after keys - before keys -> added
intersection keys -> compare item fields
```

Event performance 的 key 使用 `identityKey`。如果 `identityKey` 缺失，应在 snapshot builder 中构造稳定 fallback：

```text
performance:<artistIdentity>:<stageNormalizedName>:<eventDayId>:<startAt>:<endAt>
```

fallback 只能兜底，不能替代数据库已有的 `identityKey`。

## 8. Entity Config

### 8.1 Event Snapshot

Event 当前核心更新入口在 `server/src/controllers/event.controller.ts` 的 `updateEvent`。Event 快照必须覆盖主表和关联结构。

建议 snapshot shape：

```ts
type EventChangeSnapshotData = {
  profile: {
    name: string;
    nameI18n: unknown;
    abbreviation: string | null;
    description: string | null;
    descriptionI18n: unknown;
    eventType: string | null;
    status: string;
    officialWebsite: string | null;
    isVerified: boolean;
  };
  media: {
    coverImageUrl: string | null;
    lineupImageUrl: string | null;
    imageAssets: unknown;
  };
  organizer: {
    organizerName: string | null;
    wikiFestivalId: string | null;
  };
  location: {
    venueName: string | null;
    venueAddress: string | null;
    city: string | null;
    cityI18n: unknown;
    country: string | null;
    countryI18n: unknown;
    manualLocation: unknown;
    locationPoint: unknown;
    latitude: string | null;
    longitude: string | null;
  };
  schedule: {
    startDate: string;
    endDate: string;
    scheduleMode: string;
    timeZone: string;
    startTime: string;
    endTime: string;
    dayRolloverHour: number;
    weeks: Array<unknown>;
    eventDays: Array<unknown>;
  };
  tickets: {
    ticketUrl: string | null;
    ticketPriceMin: string | null;
    ticketPriceMax: string | null;
    ticketCurrency: string | null;
    ticketNotes: string | null;
    tiers: Array<unknown>;
  };
  lineup: {
    stages: Array<unknown>;
    artists: Array<unknown>;
    performances: Array<unknown>;
  };
  links: {
    referenceLinks: string[];
    socialLinks: unknown;
    sourceProvider: string | null;
    sourceEventUrl: string | null;
  };
};
```

Event path config：

| Path | Label | Strategy | Audience |
| --- | --- | --- | --- |
| `profile.name` | 活动名称 | scalar | public |
| `profile.description` | 活动介绍 | scalar | public |
| `profile.eventType` | 活动类型 | scalar | public |
| `profile.status` | 活动状态 | scalar | public |
| `media.coverImageUrl` | 活动封面 | scalar | public |
| `media.lineupImageUrl` | 阵容图 | scalar | public |
| `location.venueName` | 场地名称 | scalar | public |
| `location.venueAddress` | 场地地址 | scalar | public |
| `location.city` | 城市 | scalar | public |
| `location.country` | 国家/地区 | scalar | public |
| `location.manualLocation` | 地点详情 | object | public |
| `location.locationPoint` | 地图坐标 | object | public |
| `schedule.startDate` | 开始日期 | scalar | public |
| `schedule.endDate` | 结束日期 | scalar | public |
| `schedule.timeZone` | 时区 | scalar | public |
| `schedule.startTime` | 开始时间 | scalar | public |
| `schedule.endTime` | 结束时间 | scalar | public |
| `schedule.weeks` | 周期结构 | keyed-list by `weekIndex` | public |
| `schedule.eventDays` | 活动日期 | keyed-list by `eventDayId` | public |
| `tickets.ticketUrl` | 购票链接 | scalar | public |
| `tickets.ticketPriceMin` | 最低票价 | scalar | public |
| `tickets.ticketPriceMax` | 最高票价 | scalar | public |
| `tickets.tiers` | 票档 | ordered-list / keyed by `name+currency` | public |
| `lineup.stages` | 舞台 | keyed-list by `normalizedName`, order matters | public |
| `lineup.artists` | 阵容艺人 | keyed-list by `artistIdentity`, billing order matters | public |
| `lineup.performances` | 演出时间表 | keyed-list by `identityKey` | public |
| `links.referenceLinks` | 参考链接 | set | operator |
| `links.sourceProvider` | 来源平台 | scalar | private |
| `links.sourceEventUrl` | 来源链接 | scalar | private |

Event performance display：

```text
{displayNameSnapshot} · {stageName} · {eventDayLabel/localDate} {startLocalTime}-{endLocalTime}
```

Event 推送摘要示例：

```text
活动「XXX」更新了：场地名称由「Club A」改为「Club B」；Charlotte de Witte 的演出时间由「Day 2 22:00」改为「Day 2 23:30」；新增票档「VIP」。
```

### 8.2 DJ Snapshot

DJ 当前核心更新入口在 `server/src/controllers/dj.controller.ts` 的 `updateDJ`。第一版应替换这个入口里的裸 `prisma.dJ.update`，改为统一 change tracking。

建议 snapshot shape：

```ts
type DJChangeSnapshotData = {
  profile: {
    name: string;
    nameI18n: unknown;
    aliases: string[];
    genres: string[];
    bio: string | null;
    bioI18n: unknown;
    country: string | null;
    countryI18n: unknown;
    isVerified: boolean;
    honors: unknown;
  };
  media: {
    avatarUrl: string | null;
    avatarSourceUrl: string | null;
    bannerUrl: string | null;
  };
  links: {
    spotifyUrl: string | null;
    appleMusicId: string | null;
    soundcloudUrl: string | null;
    instagramUrl: string | null;
    facebookUrl: string | null;
    twitterUrl: string | null;
    youtubeUrl: string | null;
    neteaseUrl: string | null;
    qqMusicUrl: string | null;
    website: string | null;
  };
  platform: {
    spotifyId: string | null;
    spotifyFollowers: number | null;
    soundcloudId: string | null;
    trackCount: number | null;
    playlistCount: number | null;
    soundCloudFollowers: number | null;
    soundCloudFavorites: number | null;
    followerCount: number;
  };
  source: {
    sourceId: string | null;
    sourceDataSource: string | null;
    sourceGenres: string[];
    sourceLabels: string[];
    raId: string | null;
    discogsId: string | null;
    beatportId: string | null;
  };
};
```

DJ path config：

| Path | Label | Strategy | Audience |
| --- | --- | --- | --- |
| `profile.name` | DJ 名称 | scalar | public |
| `profile.aliases` | 别名 | set | public |
| `profile.genres` | 风格标签 | set | public |
| `profile.bio` | 简介 | scalar | public |
| `profile.country` | 国家/地区 | scalar | public |
| `profile.isVerified` | 认证状态 | scalar | public |
| `media.avatarUrl` | 头像 | scalar | public |
| `media.bannerUrl` | 背景图 | scalar | public |
| `links.spotifyUrl` | Spotify 链接 | scalar | public |
| `links.soundcloudUrl` | SoundCloud 链接 | scalar | public |
| `links.instagramUrl` | Instagram 链接 | scalar | public |
| `links.website` | 官网 | scalar | public |
| `platform.spotifyFollowers` | Spotify 粉丝数 | scalar | operator |
| `platform.trackCount` | 曲目数 | scalar | operator |
| `platform.followerCount` | 站内关注数 | scalar | private/system |
| `source.*` | 外部源数据 | mixed | private |

DJ 推送摘要示例：

```text
DJ「Amelie Lens」资料更新了：风格标签新增「Hard Techno」；简介由「Belgian techno DJ」改为「Belgian techno DJ and producer」；头像已更新。
```

### 8.3 Brand Snapshot

Brand 当前主要对应 Prisma `WikiFestival`，BFF 更新入口在 `server/src/routes/bff.web.routes.ts` 的 `/learn/festivals/:id` patch 流程，内容提交处理入口在 `server/src/services/content-submission-brand.service.ts`。

建议 snapshot shape：

```ts
type BrandChangeSnapshotData = {
  profile: {
    name: string;
    nameI18n: unknown;
    abbreviation: string | null;
    aliases: string[];
    tagline: string;
    introduction: string;
    descriptionI18n: unknown;
    isActive: boolean;
  };
  region: {
    country: string;
    countryI18n: unknown;
    city: string;
    cityI18n: unknown;
  };
  basics: {
    foundedYear: string;
    frequency: string;
    frequencyI18n: unknown;
  };
  media: {
    avatarUrl: string | null;
    backgroundUrl: string | null;
  };
  links: {
    officialWebsite: string | null;
    facebookUrl: string | null;
    instagramUrl: string | null;
    twitterUrl: string | null;
    youtubeUrl: string | null;
    tiktokUrl: string | null;
    links: Array<unknown>;
  };
  bindings: {
    eventIds: string[];
    postIds: string[];
    newsIds: string[];
  };
};
```

Brand path config：

| Path | Label | Strategy | Audience |
| --- | --- | --- | --- |
| `profile.name` | 主办方名称 | scalar | public |
| `profile.abbreviation` | 缩写 | scalar | public |
| `profile.aliases` | 别名 | set | public |
| `profile.tagline` | 标语 | scalar | public |
| `profile.introduction` | 介绍 | scalar | public |
| `region.country` | 国家/地区 | scalar | public |
| `region.city` | 城市 | scalar | public |
| `basics.foundedYear` | 创立年份 | scalar | public |
| `basics.frequency` | 举办频率 | scalar | public |
| `media.avatarUrl` | 头像 | scalar | public |
| `media.backgroundUrl` | 背景图 | scalar | public |
| `links.officialWebsite` | 官网 | scalar | public |
| `links.facebookUrl` | Facebook | scalar | public |
| `links.instagramUrl` | Instagram | scalar | public |
| `links.links` | 外部链接 | keyed-list by `url`, order matters | public |
| `bindings.eventIds` | 关联活动 | set | operator |
| `bindings.postIds` | 关联帖子 | set | private |
| `bindings.newsIds` | 关联资讯 | set | private |

Brand 推送摘要示例：

```text
主办方「Tomorrowland」资料更新了：城市由「Boom」改为「Antwerp」；官网由「old.example」改为「tomorrowland.com」；新增别名「TML」。
```

## 9. Visibility 与用户推送旧值/新值

用户明确要求推送显示旧值/新值。实现上必须把“是否 public-safe”做成字段级配置。

### 9.1 三层输出

| 输出 | 用途 | 内容 |
| --- | --- | --- |
| `privateSummary` | 管理员审计、排障 | 所有变化，包括 private 字段 |
| `operatorSummary` | 后台列表、运营确认 | public + operator 字段 |
| `publicSummary` | 用户推送、App 通知 | 只包含 public-safe 字段，并显示旧值/新值 |

### 9.2 public-safe 规则

允许进入用户推送：

- 活动名称、时间、地点、票价、阵容、舞台、公开链接、封面。
- DJ 名称、简介、风格、别名、公开图片、公开社交链接。
- Brand 名称、介绍、地区、公开链接、公开图片。

禁止进入用户推送：

- source provider/source URL/source IDs。
- 审核证明、内部处理状态、贡献者审核备注。
- 系统同步字段、外部爬虫 raw data。
- 站内关注数这类可能造成噪音的系统计数。
- 任何未在 config 中显式标记 public 的字段。

### 9.3 值展示格式

Display formatter 由 path config 提供：

```ts
type ValueFormatter = (value: unknown, context: FormatContext) => {
  zh: string | null;
  en: string | null;
};
```

默认格式：

| 类型 | 展示 |
| --- | --- |
| null / missing | `未设置` |
| string | 原文，长度超过 80 截断 |
| URL | domain + path 简写 |
| Date | 按实体时区格式化 |
| money | `CNY 199` / `USD 99` |
| image URL | `已设置图片` / `未设置图片`，不在 push 中展示完整 URL |
| long text | 展示截断片段 |
| array added | `新增「X」` |
| array removed | `移除「X」` |

图片变化虽然是 public-safe，但推送不应写完整 URL，应写：

```text
头像由「未设置」改为「已设置图片」
```

## 10. Summary 生成策略

### 10.1 摘要长度控制

推送摘要不能无限长。建议：

- public push 最多展示 3 条最重要变化。
- 其余变化用“等 N 处”概括。
- App 内详情页可以通过 `changeLogId` 拉取完整 public changes。

排序优先级：

1. 名称/标题变化
2. 时间/地点变化
3. 阵容/timetable 变化
4. 票务变化
5. 图片/链接变化
6. 其他资料变化

### 10.2 模板

Event：

```text
活动「{name}」更新了：{change1}；{change2}；{change3}。
```

DJ：

```text
DJ「{name}」资料更新了：{change1}；{change2}；{change3}。
```

Brand：

```text
主办方「{name}」资料更新了：{change1}；{change2}；{change3}。
```

单条字段变化：

```text
{label}由「{before}」改为「{after}」
```

新增：

```text
新增{label}「{after}」
```

删除：

```text
移除{label}「{before}」
```

## 11. EntityChangeService API

### 11.1 推荐 facade

```ts
export const entityChangeService = {
  async captureSnapshot(input: {
    entityType: EntityType;
    entityId: string;
    tx?: Prisma.TransactionClient;
  }): Promise<EntitySnapshot | null>;

  async diffSnapshots(input: {
    before: EntitySnapshot | null;
    after: EntitySnapshot | null;
    operationType: 'create' | 'update' | 'delete' | 'system_sync';
  }): Promise<EntityChangeResult>;

  async persistChange(input: {
    result: EntityChangeResult;
    actorId?: string | null;
    actorRole?: string | null;
    source?: string | null;
    sourceRoute?: string | null;
    requestId?: string | null;
    metadata?: Record<string, unknown>;
  }): Promise<EntityChangeLogRecord>;

  async trackUpdate<T>(input: {
    entityType: EntityType;
    entityId: string;
    actorId?: string | null;
    actorRole?: string | null;
    source?: string | null;
    sourceRoute?: string | null;
    requestId?: string | null;
    update: (tx: Prisma.TransactionClient) => Promise<T>;
    metadata?: Record<string, unknown>;
  }): Promise<{ value: T; changeLog: EntityChangeLogRecord | null }>;
};
```

### 11.2 `trackUpdate` 事务语义

推荐将 before、update、after 放在同一个 transaction 中：

```text
BEGIN
  before = snapshot(tx)
  value = update(tx)
  after = snapshot(tx)
COMMIT
diff outside transaction
persist change log
```

如果 diff/persist 放在 transaction 内，会增加主业务事务时长。推荐主更新事务只负责 capture before/after，diff 和 persist 可以在 commit 后执行。

如果需要强一致审计，可以将 `persistChange` 放进 transaction，但 event 更新涉及多张表，建议优先保证业务事务短小。

### 11.3 无变化处理

如果 `beforeHash === afterHash`：

- 不写 `entity_change_logs`，除非调用方显式 `persistUnchanged = true`。
- 不推送。
- 不写 admin content history。
- API 可返回 `changeLog: null`。

## 12. 接入现有更新流程

### 12.1 Event

当前 `updateEvent` 已经有复杂 transaction：

- 更新 `Event` 主表。
- 更新 ticket tiers。
- `syncStructuredEventSchedule`。
- `syncCanonicalEventLineupAndTimetable`。
- 特殊情况下 rebase existing lineup slots。

推荐改造：

```ts
const { value: event, changeLog } = await entityChangeService.trackUpdate({
  entityType: 'event',
  entityId: id,
  actorId: userId,
  actorRole: role,
  source: 'event_admin_api',
  sourceRoute: 'PUT /api/events/:id',
  update: async (tx) => {
    // 原 updateEvent transaction 内容迁移到这里，全部使用 tx
    return loadUpdatedEvent(tx, id);
  },
});
```

注意：

- `shouldRebaseExistingLineupSlots` 当前发生在第一个 transaction 后。为了 diff 准确，最终 after snapshot 必须在 rebase 后 capture。
- 如果保留两个 transaction，则 `trackUpdate` 应支持 `update` 内部执行多阶段更新，或者 event controller 手动调用 `captureBefore` / `captureAfter`。
- 推荐将 event 更新封装为 use case，controller 只负责 HTTP 参数和响应。

### 12.2 DJ

当前 `updateDJ` 是裸更新：

```ts
const dj = await prisma.dJ.update({
  where: { id },
  data: updateData,
});
```

推荐一步到位替换为：

```ts
const { value: dj, changeLog } = await entityChangeService.trackUpdate({
  entityType: 'dj',
  entityId: id,
  actorId: req.user?.userId,
  actorRole: req.user?.role,
  source: 'dj_admin_api',
  sourceRoute: 'PUT /api/djs/:id',
  update: (tx) => tx.dJ.update({
    where: { id },
    data: sanitizeDJUpdateData(req.body),
  }),
});
```

同时建议补上 DJ update data 白名单。当前裸 `req.body` 直接进入 Prisma，风险较高。新的 diff 服务不是 validation 层，但接入时应顺手把 update input 限制住。

### 12.3 Brand

Brand 用户编辑当前先创建 content submission，不直接更新 `WikiFestival`。真正写库在 `content-submission-brand.service.ts`。

推荐接入点：

- `/learn/festivals/:id` patch：仍创建 pending submission，不生成最终 diff，因为还没有真正入库。
- content submission 审核通过并执行 `createOrUpdateBrandFromSubmission` 时：用 `entityChangeService.trackUpdate` 包住实际写库。
- 如果 admin 有直接编辑 WikiFestival 的入口，也必须统一接入 `entityChangeService.trackUpdate`。

Brand revision：

- `WikiFestival.revision` 已存在。
- 更新成功时应继续 increment revision。
- `entity_change_logs.revisionBefore/revisionAfter` 读取该 revision。

## 13. 替换旧服务

### 13.1 需要废弃的文件

旧服务：

```text
server/src/services/content-submission-change-summary.service.ts
```

处理策略：

- 不再新增调用。
- 迁移完成后删除该文件。
- 所有 `attachContentSubmissionChangeSummary` 替换为 submission metadata 中记录 `changeIntent`，最终摘要由入库后的 diff 生成。
- 所有 `changeSummaryTextFromPayload` 替换为读取 `entity_change_logs.publicSummaryZh/operatorSummaryZh/privateSummaryZh`。

### 13.2 需要替换的调用点

当前调用点包括：

```text
server/src/services/content-submission-processing.service.ts
server/src/services/content-submission-event.service.ts
server/src/routes/bff.web.routes.ts
server/src/routes/content-submission.routes.ts
server/src/scripts/dj-edit-submission-regression.ts
```

替换原则：

- 提交阶段：不要声称“已修改了什么”，只记录“用户意图修改了哪些字段”用于审核 UI。
- 审核通过且入库后：读取新服务生成的 change log。
- 通知用户：使用 `publicSummaryZh` 与 `publicChanges`。
- 管理后台：使用 `operatorSummaryZh`。
- 审计详情：使用 `privateSummaryZh` 与完整 `changes`。

## 14. 通知系统接入

### 14.1 Notification metadata

推送 payload metadata 建议统一增加：

```ts
metadata: {
  route: 'event_update' | 'dj_update' | 'brand_update';
  updateKind: 'profile_change' | 'schedule_change' | 'lineup_change' | 'ticket_change' | 'media_change' | 'mixed';
  entityType: 'event' | 'dj' | 'brand';
  entityId: string;
  changeLogId: string;
  publicSummaryZh: string;
  publicChanges: Array<{
    path: string;
    label: string;
    kind: 'added' | 'removed' | 'updated' | 'reordered';
    before: string | null;
    after: string | null;
  }>;
}
```

### 14.2 用户推送 body

用户要求推送显示具体旧值/新值，body 可直接使用 public summary：

```text
活动「XXX」更新了：场地名称由「Club A」改为「Club B」；开始时间由「21:00」改为「22:00」。
```

如果变化太多：

```text
活动「XXX」更新了：场地名称由「Club A」改为「Club B」；开始时间由「21:00」改为「22:00」；阵容新增「DJ Y」等 5 处。
```

### 14.3 Admin content history

`NotificationAdminContentHistory.payload` 应保存：

```json
{
  "entityType": "event",
  "entityId": "xxx",
  "changeLogId": "yyy",
  "publicSummaryZh": "...",
  "operatorSummaryZh": "...",
  "publicChanges": [],
  "changeCount": 3
}
```

不再保存 payload 猜测式 `changeSummary`。

## 15. 审计系统接入

`AdminAuditLog.detail` 建议保存：

```json
{
  "changeLogId": "yyy",
  "beforeHash": "...",
  "afterHash": "...",
  "changeCount": 5,
  "privateSummaryZh": "...",
  "changes": []
}
```

后台审计列表读 `entity_change_logs` 即可；`admin_audit_logs` 可以作为兼容桥，避免老后台审计页面立刻失效。

长期建议：

- `entity_change_logs` 成为内容实体变更的权威审计源。
- `admin_audit_logs` 继续用于账号、安全、审核决策等非内容 diff 行为。

## 16. Registry 设计

```ts
export type EntityChangeDefinition = {
  entityType: EntityType;
  snapshotSchemaVersion: number;
  buildSnapshot: (input: {
    entityId: string;
    db: PrismaClient | Prisma.TransactionClient;
  }) => Promise<EntitySnapshot | null>;
  paths: Record<string, ChangePathConfig>;
  summarize: (input: EntityChangeSummaryInput) => EntityChangeSummary;
};

export const entityChangeRegistry = {
  event: eventChangeDefinition,
  dj: djChangeDefinition,
  brand: brandChangeDefinition,
};
```

Path config：

```ts
export type ChangePathConfig = {
  labelZh: string;
  labelEn: string;
  category: string;
  audience: ChangeAudience;
  publicSafe: boolean;
  sensitive?: boolean;
  arrayStrategy?: ArrayDiffStrategy;
  emptyStringEqualsNull?: boolean;
  formatter?: ValueFormatter;
  priority?: number;
};
```

默认原则：

- 未配置 path 默认 `private`。
- 未配置 label 的 path 不能进入 public summary。
- 未配置 formatter 的值使用通用 formatter。

## 17. Event Snapshot Builder 查询建议

Event snapshot builder 应一次性读取：

```ts
await db.event.findUnique({
  where: { id },
  include: {
    ticketTiers: { orderBy: { sortOrder: 'asc' } },
    weeks: { orderBy: { sortOrder: 'asc' } },
    eventDays: { orderBy: { sortOrder: 'asc' } },
    stages: { orderBy: { sortOrder: 'asc' } },
    canonicalArtists: {
      orderBy: { billingOrder: 'asc' },
      include: {
        members: { orderBy: { memberOrder: 'asc' } },
      },
    },
    performances: {
      orderBy: [
        { overallDayIndex: 'asc' },
        { startAt: 'asc' },
        { sortOrder: 'asc' },
      ],
      include: {
        stage: true,
        eventArtist: true,
        eventDay: true,
      },
    },
  },
});
```

Builder 输出时需要把 nested Prisma row 映射为纯 JSON，避免 Decimal、Date、Prisma JsonNull 进入 diff engine。

## 18. DJ Snapshot Builder 查询建议

```ts
await db.dJ.findUnique({
  where: { id },
});
```

第一版不强制读取 DJ 关联 event / sets，因为用户当前需求是“修改 DJ 实体对象后给出改动”。未来如果 DJ 详情页展示的“关联演出/Set”也要纳入，可以作为第二版扩展。

## 19. Brand Snapshot Builder 查询建议

```ts
await db.wikiFestival.findUnique({
  where: { id },
  include: {
    events: { select: { id: true, name: true } },
    postBindings: { select: { postId: true } },
    newsBindings: { select: { articleId: true } },
  },
});
```

第一版 public summary 不展示 post/news binding 变化，只用于 private/operator audit。

## 20. 错误处理与一致性

### 20.1 Snapshot 读取失败

如果 before snapshot 读取失败：

- 更新前实体不存在：返回 404，不进入 diff。
- builder 异常：中断更新，返回 500。不能在不知道 before 的情况下继续写入，否则审计不完整。

如果 after snapshot 读取失败：

- 主更新已成功时，不应回滚业务。
- 不写入正常的 `entity_change_logs`，因为该表只表示成功生成的变更日志。
- 打 warning/error log，并带 requestId。
- 如需自动补偿，可写入独立 retry outbox，例如 `entity_change_capture_failures`，由后台任务重新 capture after snapshot 并补生成 change log。

### 20.2 Change log 写入失败

推荐策略：

- 主业务更新优先成功。
- change log 写入失败不阻断用户保存。
- 但必须写 error log，并可进入 retry outbox。

如果管理端要求强审计，可以对 admin direct update 开启 `strictAudit = true`，写入失败则回滚。

第一版推荐：

- `event/dj/brand` 管理员更新：`strictAudit = true`。
- 系统 job 同步：`strictAudit = false`。

### 20.3 并发更新

Event 当前有 `revision`，Brand 有 `revision`，DJ 暂无 revision。

建议：

- Event / Brand 更新继续使用 revision increment。
- DJ 增加 revision 字段，或者至少用 `updatedAt` 做乐观锁辅助。
- `entity_change_logs` 记录 `revisionBefore/revisionAfter`。
- content submission 已有 `baseBrandRevision` 的思路，应推广到 event/dj edit submission。

## 21. 测试策略

### 21.1 Unit tests

覆盖：

- object key 顺序变化不产生 diff。
- set 数组顺序变化不产生 diff。
- set 数组新增/删除产生 diff。
- ordered list 重排产生 `reordered`。
- keyed list 按 key 匹配，不因顺序变化误判为删除+新增。
- null/empty string 规则符合 path config。
- public summary 不包含 private 字段。
- public summary 包含旧值/新值。

### 21.2 Entity snapshot tests

Event：

- 修改名称。
- 修改场地。
- 修改日期/时区。
- 新增/删除/修改 ticket tier。
- 新增/删除 lineup artist。
- 修改 performance start/end/stage/day。
- stage order 变化。

DJ：

- 修改名称。
- aliases 顺序变化不产生 diff。
- genres 新增/删除。
- avatar/banner 更新。
- social links 更新。
- source 字段变化只进 private。

Brand：

- 修改名称/别名。
- 修改 city/country。
- 修改 introduction。
- links 新增/删除/重排。
- event binding 变化只进 operator/private。

### 21.3 Integration tests

新增脚本建议：

```text
server/src/scripts/entity-change-event-regression.ts
server/src/scripts/entity-change-dj-regression.ts
server/src/scripts/entity-change-brand-regression.ts
```

每个脚本验证：

- 更新 API 返回 `changeLogId`。
- `entity_change_logs` 写入成功。
- `publicChanges` 包含旧值/新值。
- private 字段不进入 `publicChanges`。
- 旧 `payload.changeSummary` 不再出现。

## 22. API Response 建议

更新接口响应建议统一增加：

```json
{
  "data": {},
  "change": {
    "changeLogId": "uuid",
    "changed": true,
    "changeCount": 3,
    "summary": "活动「XXX」更新了：场地名称由「A」改为「B」。",
    "publicChanges": [
      {
        "path": "location.venueName",
        "label": "场地名称",
        "kind": "updated",
        "before": "A",
        "after": "B"
      }
    ]
  }
}
```

如果为了兼容旧客户端，第一版可以保留原响应实体，并额外挂：

```json
{
  "...eventFields": "...",
  "change": {}
}
```

## 23. 改造执行追踪

本节是本次改造的唯一执行看板。后续每次改动代码，都必须同步更新本节，避免实现过程中范围发散、阶段遗漏、或者改完代码但设计状态失真。

### 23.1 追踪规则

执行规则：

- 每次开始改某个阶段前，先把对应 checklist 标记为进行中说明。
- 每次提交代码改动后，必须在 `23.3 变更流水` 新增一行，写清楚改了哪些文件、完成了哪个 checklist、验证了什么。
- 每次完成一个 checklist 项，必须把 `[ ]` 改成 `[x]`，并补充验证方式。
- 如果发现原计划不适用，必须先在本节写明“调整原因”和“新边界”，再改代码。
- 第一波范围锁定为 `event`、`dj`、`brand(WikiFestival)`，不得在本轮顺手扩展 `djSet/news/post/label`。
- 旧 `content-submission-change-summary.service.ts` 不再新增能力，只允许被替换和删除。
- 用户推送必须保留 public-safe 字段的旧值/新值；任何删除或弱化这点的改动都需要重新确认。

状态约定：

| 标记 | 含义 |
| --- | --- |
| `[ ]` | 未开始 |
| `[x]` | 已完成并验证 |
| `Blocked:` | 阻塞，必须写明原因和下一步 |
| `Changed:` | 计划有调整，必须写明调整原因 |

### 23.2 阶段 Checklist

#### Phase 0: 边界冻结与基线确认

- [x] 确认第一波实体范围：`event`、`dj`、`brand(WikiFestival)`。
- [x] 确认用户推送需要展示旧值/新值。
- [x] 确认长期不保存完整 before/after snapshot。
- [x] 确认旧 payload 猜测式 summary 直接废弃。
- [ ] 记录当前所有旧 summary 调用点的最终替换清单。
- [ ] 确认本轮不扩展 `djSet/news/post/label`。

验收方式：

- 本文档 `## 2. 已确认产品决策` 与本 checklist 保持一致。
- `rg "content-submission-change-summary|changeSummaryTextFromPayload|attachContentSubmissionChangeSummary" server/src` 输出被记录到替换清单。

#### Phase 1: 数据库与持久化模型

- [ ] 新增 Prisma model `EntityChangeLog`。
- [ ] 新增 migration 创建 `entity_change_logs`。
- [ ] 确认 `changes`、`public_changes`、summary、hash、revision 字段齐全。
- [ ] 增加索引：`entityType/entityId/createdAt`、`actorId/createdAt`、`operationType/createdAt`。
- [ ] 运行 Prisma generate。
- [ ] 验证 migration 可在本地数据库应用。

验收方式：

- `pnpm prisma generate` 成功。
- migration SQL 中不包含完整 snapshot 字段。
- 能通过 Prisma 创建一条测试 `EntityChangeLog`。

#### Phase 2: 核心 entity-change 模块骨架

- [ ] 新增 `server/src/modules/entity-change/index.ts`。
- [ ] 新增 `entity-change.types.ts`。
- [ ] 新增 `entity-change.registry.ts`。
- [ ] 新增 `entity-change.service.ts` facade。
- [ ] 新增 `entity-change.repository.ts`。
- [ ] 新增 `entity-change-canonicalizer.ts`。
- [ ] 新增 `entity-change-diff-engine.ts`。
- [ ] 新增 `entity-change-summarizer.ts`。
- [ ] 新增 `entity-change-visibility.ts`。
- [ ] 提供 `trackUpdate`、`captureSnapshot`、`diffSnapshots`、`persistChange` API。

验收方式：

- TypeScript 编译通过。
- 空 registry 时有明确错误，不静默失败。
- `beforeHash === afterHash` 时不写 change log。

#### Phase 3: Canonicalizer 与 Diff Engine

- [ ] object key 排序稳定。
- [ ] Date 统一 ISO。
- [ ] Decimal 统一 string。
- [ ] i18n JSON key 顺序稳定。
- [ ] 支持 scalar diff。
- [ ] 支持 set array diff。
- [ ] 支持 ordered-list diff。
- [ ] 支持 keyed-list diff。
- [ ] 支持 hash tree 剪枝。
- [ ] 支持 path config 控制 empty string/null 语义。
- [ ] 支持 public/private/operator visibility 分类。

验收方式：

- 单测覆盖对象 key 顺序变化不产生 diff。
- 单测覆盖 set 数组顺序变化不产生 diff。
- 单测覆盖 keyed-list 不因顺序变化误判新增/删除。
- 单测覆盖 public summary 不包含 private 字段。

#### Phase 4: Event 接入

- [ ] 新增 `snapshots/event.snapshot.ts`。
- [ ] 新增 `configs/event.change-config.ts`。
- [ ] Event snapshot 覆盖主表 profile/media/location/schedule/tickets/lineup/links。
- [ ] Event snapshot 读取 `ticketTiers`。
- [ ] Event snapshot 读取 `weeks`、`eventDays`。
- [ ] Event snapshot 读取 `stages`。
- [ ] Event snapshot 读取 `canonicalArtists` 和 members。
- [ ] Event snapshot 读取 `performances`，并使用 `identityKey`。
- [ ] 改造 `updateEvent` 使用 `entityChangeService`。
- [ ] 处理 `shouldRebaseExistingLineupSlots` 后再 capture after snapshot。
- [ ] API 响应增加 `change` 字段，保持旧客户端兼容。
- [ ] Event 更新成功写入 `entity_change_logs`。

验收方式：

- 修改活动名称生成 name diff。
- 修改场地生成 location diff。
- 修改 ticket tier 生成 added/removed/updated diff。
- 修改 performance 时间生成具体 timetable diff。
- lineup/timetable 顺序变化不误判整组替换。

#### Phase 5: DJ 接入

- [ ] 新增 `snapshots/dj.snapshot.ts`。
- [ ] 新增 `configs/dj.change-config.ts`。
- [ ] DJ snapshot 覆盖 profile/media/links/platform/source。
- [ ] `aliases` 使用 set 语义。
- [ ] `genres` 使用 set 语义。
- [ ] `source.*` 默认 private。
- [ ] 改造 `updateDJ` 使用 `entityChangeService`。
- [ ] 为 `updateDJ` 增加 update input 白名单。
- [ ] API 响应增加 `change` 字段，保持旧客户端兼容。
- [ ] DJ 更新成功写入 `entity_change_logs`。

验收方式：

- aliases 调整顺序不生成 diff。
- genres 新增/删除生成 diff。
- avatar/banner 更新生成 public diff。
- source 字段变化不进入 publicChanges。

#### Phase 6: Brand(WikiFestival) 接入

- [ ] 新增 `snapshots/brand.snapshot.ts`。
- [ ] 新增 `configs/brand.change-config.ts`。
- [ ] Brand snapshot 覆盖 profile/region/basics/media/links/bindings。
- [ ] `aliases` 使用 set 语义。
- [ ] `links.links` 使用 keyed-list by `url`。
- [ ] `bindings.eventIds` 进入 operator，不进入 public。
- [ ] `bindings.postIds/newsIds` 进入 private。
- [ ] 在 `content-submission-brand.service.ts` 实际写库路径接入 `entityChangeService`。
- [ ] Brand revisionBefore/revisionAfter 写入 change log。
- [ ] 审核通过后通知使用新生成的 change log。

验收方式：

- 修改 city/country 生成 public diff。
- 修改 officialWebsite 生成旧值/新值 public diff。
- aliases 顺序变化不生成 diff。
- post/news binding 不进入用户推送。

#### Phase 7: 旧 summary 删除与调用点替换

- [ ] 删除 `content-submission-change-summary.service.ts`。
- [ ] 替换 `content-submission-processing.service.ts` 中的 `changeSummaryTextFromPayload`。
- [ ] 替换 `content-submission-event.service.ts` 中的 `changeSummaryTextFromPayload`。
- [ ] 替换 `bff.web.routes.ts` 中的 `attachContentSubmissionChangeSummary`。
- [ ] 替换 `bff.web.routes.ts` 中的 `changeSummaryTextFromPayload`。
- [ ] 替换 `content-submission.routes.ts` 中的旧 summary 调用。
- [ ] 更新或删除 `dj-edit-submission-regression.ts` 中旧 summary 断言。
- [ ] 确认 `rg "content-submission-change-summary|changeSummaryTextFromPayload|attachContentSubmissionChangeSummary" server/src` 无生产调用。

验收方式：

- 全仓搜索无旧 summary 生产调用。
- content submission 审核通过后的摘要来自 `entity_change_logs`。

#### Phase 8: Notification 与 Admin History 接入

- [ ] notification metadata 增加 `changeLogId`。
- [ ] notification metadata 增加 `publicChanges`。
- [ ] `event_update` 推送 body 使用 `publicSummaryZh`。
- [ ] `dj_update` 推送 body 使用 `publicSummaryZh`。
- [ ] `brand_update` 推送 body 使用 `publicSummaryZh`。
- [ ] `NotificationAdminContentHistory.payload` 改为引用 `changeLogId`。
- [ ] `AdminAuditLog.detail` 写入 `changeLogId` 和 private summary。
- [ ] iOS 现有 `event_update`、`dj_update`、`brand_update` route metadata 保持兼容。

验收方式：

- 用户推送 body 包含旧值/新值。
- 用户推送 metadata 不包含 private changes。
- admin content history 可以打开并展示 change log 摘要。

#### Phase 9: 测试、回归脚本与验收

- [ ] 新增 canonicalizer 单测。
- [ ] 新增 diff engine 单测。
- [ ] 新增 event snapshot/diff 单测。
- [ ] 新增 dj snapshot/diff 单测。
- [ ] 新增 brand snapshot/diff 单测。
- [ ] 新增 `entity-change-event-regression.ts`。
- [ ] 新增 `entity-change-dj-regression.ts`。
- [ ] 新增 `entity-change-brand-regression.ts`。
- [ ] 跑 TypeScript typecheck。
- [ ] 跑相关 regression scripts。
- [ ] 更新本文档 `23.3 变更流水` 和最终验收状态。

验收方式：

- 所有新增单测通过。
- 三个实体的 regression script 通过。
- `rg` 确认旧 summary 已清理。

#### Phase 10: 清理与交付

- [ ] 删除不再使用的 imports、types、scripts。
- [ ] 更新 README 或后台开发说明中的变更摘要来源。
- [ ] 确认没有把完整 snapshot 写入持久化表。
- [ ] 确认没有把 private 字段写入 publicChanges。
- [ ] 确认所有代码变更都已在 `23.3 变更流水` 记录。
- [ ] 最终复查 `git diff`，确认无无关回滚。

验收方式：

- `git diff` 只包含本次改造相关变更。
- 本文档 checklist 与实际代码状态一致。

### 23.3 变更流水

每次代码改动都必须新增一行。只改文档也要记录，方便回看设计演进。

| 日期 | 阶段 | 文件 | 变更摘要 | 验证 | 状态 |
| --- | --- | --- | --- | --- | --- |
| 2026-06-04 | Phase 0 | `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 新建设计文档，确认第一批范围、存储策略、推送旧值/新值、旧服务废弃策略 | `wc -l`、`rg` 检查关键决策 | Done |
| 2026-06-04 | Phase 0 | `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 新增分阶段 checklist、追踪规则、变更流水，作为后续改造唯一执行看板 | 人工复查章节结构 | Done |

## 24. 验收标准

功能验收：

- Event 任意主字段修改后，能看到具体 path、旧值、新值。
- Event ticket/lineup/timetable 修改后，不误判整组替换，而能指出新增/删除/修改的具体 item。
- DJ genres/aliases 调整顺序不会产生 diff。
- Brand aliases 调整顺序不会产生 diff。
- 用户推送包含旧值/新值。
- 用户推送不包含 private 字段。
- 后台审计能看到 private 完整 changes。
- 旧 payload 猜测式 summary 不再参与生产流程。

数据验收：

- `entity_change_logs.beforeHash` / `afterHash` 稳定。
- 同一等价结构重复 canonicalize hash 一致。
- 无变化更新不写 change log、不推送。
- revisionBefore/revisionAfter 与实体 revision 对齐。

兼容验收：

- 原有 event/dj/brand 更新 API 不破坏客户端必需字段。
- notification center 现有 route：`event_update`、`dj_update`、`brand_update` 仍可被 iOS 消费。
- `NotificationAdminContentHistory` 仍能展示发布历史，但 payload 改为引用 `changeLogId`。

## 25. 关键设计取舍

### 25.1 为什么不用 payload diff

payload diff 只能说明“用户提交了什么”，不能说明“最终数据库变成了什么”。例如：

- 后端 normalize 可能改变值。
- transaction 可能同步更新关联表。
- clear flag 可能变成 null。
- event schedule 更新会影响 weeks/eventDays/performances。
- brand submission 审核通过后才真正写库。

因此权威 diff 必须来自 before/after snapshot。

### 25.2 为什么不用数据库 trigger

数据库 trigger 可以捕获 row 变化，但不理解业务语义：

- 不知道 `genres` 是无序集合。
- 不知道 `EventPerformance.identityKey` 才是 timetable item 的身份。
- 不知道哪些字段能推送给用户。
- 不知道如何生成中文摘要。

本方案把 trigger 能做的“变了”升级为领域服务能做的“业务上具体变了什么”。

### 25.3 为什么 hash tree 仍然有价值

第一批实体的数据量不一定大，但 hash tree 有三个价值：

- 跳过未变化子树，避免复杂 event 快照递归成本过高。
- 保证 canonical equivalence，例如对象 key 顺序变化不产生 diff。
- 为未来缓存和增量 diff 留接口。

## 26. 未来扩展

暂不纳入第一波，但架构应保留能力：

- `djSet`：曲目列表和视频元数据 diff。
- `news/post`：内容绑定和正文摘要 diff。
- `label`：厂牌资料 diff。
- Snapshot 短期归档与回滚。
- App 内“查看完整修改详情”页面。
- 多语言 summary：英文、日文。
- 操作冲突检测：基于 revision 的 compare-and-swap。

## 27. 最终结论

本方案的核心不是“写一个 deep diff 工具”，而是建立一个统一的内容变更领域服务：

- Snapshot builder 决定“什么是这个实体的业务状态”。
- Canonicalizer 决定“哪些结构等价”。
- Diff engine 决定“哪里变了”。
- Config 决定“数组语义、字段标签、可见性、安全性”。
- Summarizer 决定“用户和运营如何理解这次变化”。
- Repository 决定“审计和通知如何稳定追踪这次变化”。

第一批只接 `event`、`dj`、`brand`，但模块形态保持 registry 化。这样既能一步到位替换旧 summary，又不会把未来实体支持提前混进第一波实现里。
