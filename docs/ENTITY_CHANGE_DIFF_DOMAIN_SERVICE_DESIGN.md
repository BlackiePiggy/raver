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
- [x] 记录当前所有旧 summary 调用点的最终替换清单。
- [x] 确认本轮不扩展 `djSet/news/post/label`。

验收方式：

- 本文档 `## 2. 已确认产品决策` 与本 checklist 保持一致。
- `rg "content-submission-change-summary|changeSummaryTextFromPayload|attachContentSubmissionChangeSummary" server/src` 输出被记录到替换清单。

#### Phase 1: 数据库与持久化模型

- [x] 新增 Prisma model `EntityChangeLog`。
- [x] 新增 migration 创建 `entity_change_logs`。
- [x] 确认 `changes`、`public_changes`、summary、hash、revision 字段齐全。
- [x] 增加索引：`entityType/entityId/createdAt`、`actorId/createdAt`、`operationType/createdAt`。
- [x] 运行 Prisma generate。
- [x] 验证 migration 可在本地数据库应用。已通过 `pnpm prisma migrate deploy` 应用 `20260605103000_add_entity_change_logs`，并通过事务内写入后回滚验证 `EntityChangeLog` 可创建。

验收方式：

- `pnpm prisma generate` 成功。
- migration SQL 中不包含完整 snapshot 字段。
- 能通过 Prisma 创建一条测试 `EntityChangeLog`。

#### Phase 2: 核心 entity-change 模块骨架

- [x] 新增 `server/src/modules/entity-change/index.ts`。
- [x] 新增 `entity-change.types.ts`。
- [x] 新增 `entity-change.registry.ts`。
- [x] 新增 `entity-change.service.ts` facade。
- [x] 新增 `entity-change.repository.ts`。
- [x] 新增 `entity-change-canonicalizer.ts`。
- [x] 新增 `entity-change-diff-engine.ts`。
- [x] 新增 `entity-change-summarizer.ts`。
- [x] 新增 `entity-change-visibility.ts`。
- [x] 提供 `trackUpdate`、`captureSnapshot`、`diffSnapshots`、`persistChange` API。

验收方式：

- TypeScript 编译通过。
- 空 registry 时有明确错误，不静默失败。
- `beforeHash === afterHash` 时不写 change log。

#### Phase 3: Canonicalizer 与 Diff Engine

- [x] object key 排序稳定。
- [x] Date 统一 ISO。
- [x] Decimal 统一 string。
- [x] i18n JSON key 顺序稳定。
- [x] 支持 scalar diff。
- [x] 支持 set array diff。
- [x] 支持 ordered-list diff。
- [x] 支持 keyed-list diff。
- [x] 支持 hash tree 剪枝。
- [x] 支持 path config 控制 empty string/null 语义。
- [x] 支持 public/private/operator visibility 分类。

验收方式：

- 单测覆盖对象 key 顺序变化不产生 diff。
- 单测覆盖 set 数组顺序变化不产生 diff。
- 单测覆盖 keyed-list 不因顺序变化误判新增/删除。
- 单测覆盖 public summary 不包含 private 字段。

#### Phase 4: Event 接入

- [x] 新增 `snapshots/event.snapshot.ts`。
- [x] 新增 `configs/event.change-config.ts`。
- [x] Event snapshot 覆盖主表 profile/media/location/schedule/tickets/lineup/links。
- [x] Event snapshot 读取 `ticketTiers`。
- [x] Event snapshot 读取 `weeks`、`eventDays`。
- [x] Event snapshot 读取 `stages`。
- [x] Event snapshot 读取 `canonicalArtists` 和 members。
- [x] Event snapshot 读取 `performances`，并使用 `identityKey`。
- [x] 改造 `updateEvent` 使用 `entityChangeService`。
- [x] 处理 `shouldRebaseExistingLineupSlots` 后再 capture after snapshot。
- [x] API 响应增加 `change` 字段，保持旧客户端兼容。
- [x] Event 更新成功写入 `entity_change_logs`。
- [x] Event content submission 入库路径生成 `entity_change_logs`。

验收方式：

- 修改活动名称生成 name diff。
- 修改场地生成 location diff。
- 修改 ticket tier 生成 added/removed/updated diff。
- 修改 performance 时间生成具体 timetable diff。
- lineup/timetable 顺序变化不误判整组替换。

#### Phase 5: DJ 接入

- [x] 新增 `snapshots/dj.snapshot.ts`。
- [x] 新增 `configs/dj.change-config.ts`。
- [x] DJ snapshot 覆盖 profile/media/links/platform/source。
- [x] `aliases` 使用 set 语义。
- [x] `genres` 使用 set 语义。
- [x] `source.*` 默认 private。
- [x] 改造 `updateDJ` 使用 `entityChangeService`。
- [x] 为 `updateDJ` 增加 update input 白名单。
- [x] API 响应增加 `change` 字段，保持旧客户端兼容。
- [x] DJ 更新成功写入 `entity_change_logs`。
- [x] DJ content submission 入库路径生成 `entity_change_logs`。

验收方式：

- aliases 调整顺序不生成 diff。
- genres 新增/删除生成 diff。
- avatar/banner 更新生成 public diff。
- source 字段变化不进入 publicChanges。

#### Phase 6: Brand(WikiFestival) 接入

- [x] 新增 `snapshots/brand.snapshot.ts`。
- [x] 新增 `configs/brand.change-config.ts`。
- [x] Brand snapshot 覆盖 profile/region/basics/media/links/bindings。
- [x] `aliases` 使用 set 语义。
- [x] `links.links` 使用 keyed-list by `url`。
- [x] `bindings.eventIds` 进入 operator，不进入 public。
- [x] `bindings.postIds/newsIds` 进入 private。
- [x] 在 `content-submission-brand.service.ts` 实际写库路径接入 `entityChangeService`。
- [x] Brand revisionBefore/revisionAfter 写入 change log。
- [x] 审核通过后通知使用新生成的 change log。

验收方式：

- 修改 city/country 生成 public diff。
- 修改 officialWebsite 生成旧值/新值 public diff。
- aliases 顺序变化不生成 diff。
- post/news binding 不进入用户推送。

#### Phase 7: 旧 summary 删除与调用点替换

- [x] 删除 `content-submission-change-summary.service.ts`。
- [x] 替换 `content-submission-processing.service.ts` 中的 `changeSummaryTextFromPayload`。
- [x] 替换 `content-submission-event.service.ts` 中的 `changeSummaryTextFromPayload`。
- [x] 替换 `bff.web.routes.ts` 中的 `attachContentSubmissionChangeSummary`。
- [x] 替换 `bff.web.routes.ts` 中的 `changeSummaryTextFromPayload`。
- [x] 替换 `content-submission.routes.ts` 中的旧 summary 调用。
- [x] 更新或删除 `dj-edit-submission-regression.ts` 中旧 summary 断言。
- [x] 确认 `rg "content-submission-change-summary|changeSummaryTextFromPayload|attachContentSubmissionChangeSummary" server/src` 无生产调用。

验收方式：

- 全仓搜索无旧 summary 生产调用。
- content submission 审核通过后的摘要来自 `entity_change_logs`。

#### Phase 8: Notification 与 Admin History 接入

- [x] notification metadata 增加 `changeLogId`。
- [x] notification metadata 增加 `publicChanges`。
- [x] `event_update` 推送 body 使用 `publicSummaryZh`。
- [x] `dj_update` 推送 body 使用 `publicSummaryZh`。
- [x] `brand_update` 推送 body 使用 `publicSummaryZh`。
- [x] `NotificationAdminContentHistory.payload` 改为引用 `changeLogId`。
- [x] `AdminAuditLog.detail` 写入 `changeLogId` 和 private summary。
- [x] iOS 现有 `event_update`、`dj_update`、`brand_update` route metadata 保持兼容。

验收方式：

- 用户推送 body 包含旧值/新值。
- 用户推送 metadata 不包含 private changes。
- admin content history 可以打开并展示 change log 摘要。

#### Phase 9: 测试、回归脚本与验收

- [x] 新增 canonicalizer 单测。
- [x] 新增 diff engine 单测。
- [x] 新增 event snapshot/diff 单测。
- [x] 新增 dj snapshot/diff 单测。
- [x] 新增 brand snapshot/diff 单测。
- [x] 新增 `entity-change-event-regression.ts`。
- [x] 新增 `entity-change-dj-regression.ts`。
- [x] 新增 `entity-change-brand-regression.ts`。
- [x] 跑 TypeScript typecheck。
- [x] 跑相关 regression scripts。
- [x] 更新本文档 `23.3 变更流水` 和最终验收状态。

验收方式：

- 所有新增单测通过。
- 三个实体的 regression script 通过。
- `rg` 确认旧 summary 已清理。

#### Phase 10: 清理与交付

- [x] 删除不再使用的 imports、types、scripts。
- [x] 更新 README 或后台开发说明中的变更摘要来源。
- [x] 确认没有把完整 snapshot 写入持久化表。
- [x] 确认没有把 private 字段写入 publicChanges。
- [x] 确认所有代码变更都已在 `23.3 变更流水` 记录。
- [x] 最终复查 `git diff`，确认无无关回滚。已按 `docs`/`server` 范围复查；工作区仍存在本轮外的 submodule 脏状态，未触碰也不纳入本次交付。

验收方式：

- `git diff` 只包含本次改造相关变更。
- 本文档 checklist 与实际代码状态一致。

#### Phase 11: DJSet 扩展接入

> 第一波 `event/dj/brand` 已完成。本阶段从 `## 26. 未来扩展` 中选择第一项 `djSet` 进入第二阶段开发，仍沿用同一个领域级服务，不另起旧式 summary。

- [x] 扩展 `EntityChangeEntityType` 支持 `djSet`。
- [x] 新增 `snapshots/dj-set.snapshot.ts`，覆盖 profile/video/media/recording/lineup/tracks。
- [x] 新增 `configs/dj-set.change-config.ts`，定义 public/operator/private 可见性。
- [x] `customDjNames`/lineup 使用 set 或 keyed-list 语义，避免顺序误判。
- [x] `tracks` 使用 keyed-list by `identityKey`，曲名/艺人/时间/平台链接修改给出具体旧值/新值。
- [x] `createDJSet` 写入 `entity_change_logs`，operationType=`create`。
- [x] `updateDJSetByUploader` 写入 `entity_change_logs`，operationType=`update`。
- [x] `addTrack` 与 `batchAddTracks` 写入 `entity_change_logs`，operationType=`update`。
- [x] `replaceTracksByUploader` 写入 `entity_change_logs`，operationType=`update`。
- [x] `deleteDJSetByUploader` 写入 `entity_change_logs`，operationType=`delete`。
- [x] DJSet API 响应 additive 增加 `change` 字段，保持旧客户端兼容。
- [x] 新增 `entity-change-dj-set-regression.ts` 并加入 package scripts。
- [x] 更新模块 README，说明第二阶段已接入 `djSet`。
- [x] 跑 build、schema validate、core/event/dj/brand/djSet regression。
- [x] 更新本文档 `23.3 变更流水` 和 Phase 11 最终状态。

验收方式：

- 创建 DJSet 生成 create diff。
- 修改标题/封面/场地/录制时间生成 public diff。
- lineup/customDjNames 顺序变化不误判整组替换。
- tracks 新增/删除/修改能定位到具体曲目。
- 删除 DJSet 生成 delete diff，但不保存完整 before snapshot。
- 旧 `event/dj/brand` regression 继续通过。

#### Phase 12: 多语言 Summary 与 App 修改详情页

> 将 `## 26. 未来扩展` 中的“多语言 summary：英文、日文”和“App 内查看完整修改详情页面”正式纳入落地范围。英文 summary 已有基础字段，本阶段补齐日文字段、公开详情 API 和 iOS 页面入口。

- [x] Prisma `EntityChangeLog` 新增 `privateSummaryJa/operatorSummaryJa/publicSummaryJa`。
- [x] 新增 migration 为 `entity_change_logs` 增加日文 summary 列。
- [x] `EntityChangeSummary` 类型增加 Ja 字段。
- [x] summarizer 生成 private/operator/public 日文摘要。
- [x] repository 持久化 Ja summary。
- [x] response/detail API 返回 zh/en/ja summaries。
- [x] public detail API 只返回 `publicChanges`，不泄露 private/operator changes。
- [x] notification metadata 增加 `publicSummaryEn/publicSummaryJa`，兼容旧字段。
- [x] iOS model 支持 `changeLogId` 和 public change detail DTO。
- [x] iOS repository/service 增加 fetch entity change detail。
- [x] iOS 新增“修改详情”页面，展示 summary 与旧值/新值列表。
- [x] iOS 通知列表点击有 `changeLogId` 的更新通知时进入修改详情页。
- [x] 新增/更新 regression，覆盖英文/日文 summary 和 public detail API payload。
- [x] 跑 Prisma validate、build、entity-change regressions 和 iOS Swift 编译/静态检查可行项。iOS `xcodebuild -list` 通过；完整 simulator build 已尝试，但被外部 SwiftPM 依赖 `_OpenAPIGeneratorCore` 的既有编译限制阻塞，尚未进入 App Swift 文件编译。
- [x] 更新本文档 `23.3 变更流水` 和 Phase 12 最终状态。

验收方式：

- 新生成 change log 同时保存 zh/en/ja summary。
- 老 change log 缺少 Ja 时 API/UI fallback，不崩溃。
- App 修改详情页只展示 public-safe 字段旧值/新值。
- notification metadata 中 `changeLogId` 可驱动 App 详情页。
- private/operator changes 不进入 public detail API。

#### Phase 13: News/Post 内容绑定与正文摘要 Diff

> 从 `## 26. 未来扩展` 继续推进 `news/post`。本阶段先接入审核通过后的实际创建路径：`news` 使用 `NewsArticle`，`post` 使用 `Post`，并统一记录正文/媒体/绑定关系的 create diff。后续如果出现独立编辑入口，再沿用同一 snapshot/config 追加 update/delete 路径。

- [x] 扩展 `EntityChangeEntityType` 支持 `news`、`post`。
- [x] 新增 `snapshots/news.snapshot.ts`，覆盖 profile/media/publish/bindings。
- [x] 新增 `configs/news.change-config.ts`，定义 title/summary/body/cover/link/bindings 可见性。
- [x] 新增 `snapshots/post.snapshot.ts`，覆盖 content/media/context/stats/bindings。
- [x] 新增 `configs/post.change-config.ts`，定义 content/images/location/type/visibility/bindings 可见性。
- [x] `bindings.djIds/brandIds/eventIds` 使用 set 语义，避免顺序变化误判。
- [x] `createNewsFromSubmission` 写入 `entity_change_logs`，operationType=`create`。
- [x] `createIDFromSubmission` 写入 `entity_change_logs`，operationType=`create`。
- [x] submission history latest change helper 支持 `news`、`post`，继续返回 `changeLogId/publicSummary*/publicChanges`。
- [x] notification/history metadata 可引用 news/post change log，但不破坏原有事件/DJ/品牌通知。
- [x] 新增 `entity-change-news-post-regression.ts` 并加入 package scripts。
- [x] 更新模块 README，说明第三阶段已接入 `news/post`。
- [x] 跑 build、schema validate、core/event/dj/brand/djSet/newsPost regression。
- [x] 更新本文档 `23.3 变更流水` 和 Phase 13 最终状态。

验收方式：

- News create 生成 create diff，能展示标题、摘要、正文摘要、封面、链接、绑定关系。
- Post create 生成 create diff，能展示内容摘要、图片、类型、可见性、绑定关系。
- DJ/Event/Brand 绑定顺序变化不产生噪音 diff。
- public detail API 对 news/post 仍只展示 public-safe fields。
- 旧 event/dj/brand/djSet regression 继续通过。

#### Phase 14: Label 厂牌资料 Diff

> 从 `## 26. 未来扩展` 继续推进 `label`。本阶段先覆盖审核通过后的 `Label` 创建路径，并把 profile/media/region/genres/contact/links/founder 等资料纳入统一领域级 diff。后续如出现独立编辑入口，再复用同一 snapshot/config 接入 update/delete。

- [x] 扩展 `EntityChangeEntityType` 支持 `label`。
- [x] 新增 `snapshots/label.snapshot.ts`，覆盖 profile/source/media/region/music/contact/links/founder/stats。
- [x] 新增 `configs/label.change-config.ts`，定义 public/operator/private 可见性。
- [x] `genres` 使用 set 语义，避免顺序变化误判。
- [x] `contacts`、`linksInWeb` 规范化 JSON，避免 key 顺序噪音。
- [x] `createLabelFromSubmission` 写入 `entity_change_logs`，operationType=`create`。
- [x] submission history latest change helper 支持 `label`，继续返回 `changeLogId/publicSummary*/publicChanges`。
- [x] notification/history metadata 可引用 label change log，保持现有 `brand_release`/`label` 兼容。
- [x] 新增 `entity-change-label-regression.ts` 并加入 package scripts。
- [x] 更新模块 README，说明第四阶段已接入 `label`。
- [x] 跑 build、schema validate、core/event/dj/brand/djSet/newsPost/label regression。
- [x] 更新本文档 `23.3 变更流水` 和 Phase 14 最终状态。

验收方式：

- Label create 生成 create diff，能展示名称、简介、图片、国家/地区、genres、链接与 founder 信息。
- contacts、sourcePage、sourceListingUrl、cardId 等非公开字段不进入 publicChanges。
- genres 顺序变化不产生 diff。
- 旧 event/dj/brand/djSet/news/post regression 继续通过。

#### Phase 15: Snapshot 短期归档与回滚基础

> 从 `## 26. 未来扩展` 继续推进 Snapshot 短期归档。仍遵守 Phase 0 的长期隐私边界：`entity_change_logs` 不长期保存完整 before/after snapshot；本阶段新增独立短期归档表，给运营审计、短期排查和后续回滚能力提供基础数据。

- [x] 启动 Phase 15 checklist，明确短期归档不改变 `entity_change_logs` 长期存储边界。
- [x] Prisma 新增 `EntityChangeSnapshotArchive` model，独立保存 before/after snapshot。已在 `schema.prisma` 增加独立 model，未向 `EntityChangeLog` 增加完整 snapshot 字段。
- [x] 新增 migration 创建 `entity_change_snapshot_archives`，包含 `expires_at` 和必要索引。已新增 `20260605143000_add_entity_change_snapshot_archives`。
- [x] `PersistEntityChangeInput` 支持携带 before/after snapshots。已新增 `snapshots` 和可选 `snapshotArchiveRetentionDays`。
- [x] repository 在创建 change log 后同事务写入短期 snapshot archive。已通过 Prisma transaction 同步创建 log 与 archives。
- [x] `trackUpdate` 自动把 capture 到的 before/after snapshot 传给 repository。
- [x] 手动 `diffSnapshots` + `persistChange` 调用点补齐 snapshots 传递。已覆盖 Event、content submission event/dj/brand/news/post/label、DJSet create/delete。
- [x] 新增归档 regression，覆盖 create/update/delete/no-change 场景。已新增 `entity-change-snapshot-archive-regression.ts`。
- [x] 新增 snapshot archive 清理脚本，按 `expiresAt` 删除过期归档。默认 dry-run，`cleanup:apply` 执行删除。
- [x] 更新模块 README，说明短期归档用途、隐私边界与 TTL。
- [x] 跑 Prisma generate/validate、build、全量 entity-change regressions。已通过 `pnpm prisma:generate`、`pnpm prisma validate`、`pnpm prisma migrate deploy`、`pnpm build`、全量 entity-change regression 和 cleanup dry-run。
- [x] 更新本文档 `23.3 变更流水` 和 Phase 15 最终状态。

验收方式：

- 新生成 change log 在有 before/after snapshot 时同步写入短期 archive。
- create 只归档 after，delete 只归档 before，update 归档 before/after。
- 无变化更新不写 change log，也不写 archive。
- archive 有明确 `expiresAt`，可被清理脚本删除。
- public detail API 仍不暴露完整 snapshot。
- `entity_change_logs` 仍不新增完整 snapshot 字段。

#### Phase 16: Revision Compare-And-Swap 冲突检测

> 从 `## 26. 未来扩展` 推进最后一项“操作冲突检测”。本阶段先把 CAS 能力沉入 entity-change 领域模块，并在已有稳定 revision 的 `event` 与 `brand(WikiFestival)` 更新路径启用强校验；`dj/djSet/news/post/label` 暂无统一 revision 字段，本阶段只保留扩展 hook，不强行改 schema。

- [x] 启动 Phase 16 checklist，明确第一版 CAS 范围为 Event/Brand。
- [x] 新增 entity-change revision guard，统一解析 expected/base revision 并输出 409 conflict error。已新增 `entity-change-revision-guard.ts`。
- [x] `trackUpdate` 支持 `expectedRevision`，为未来 revision 实体提供统一 hook。
- [x] Event 管理更新入口支持 `expectedRevision/baseRevision/revision`，并在 update where 中使用 revision CAS。
- [x] Event CAS 冲突返回 409，不写 change log，不写 snapshot archive。已在 update CAS miss 时抛出 `EntityChangeRevisionConflictError`。
- [x] Brand content submission apply 保持 `baseBrandRevision` 校验，并在实际 `WikiFestival.update` 时增加 revision CAS。
- [x] Brand CAS 冲突继续返回既有 `BRAND_SUBMISSION_STALE_EDIT` 409。
- [x] 新增 revision guard regression，覆盖解析、匹配、冲突错误。已新增 `entity-change-revision-guard-regression.ts`。
- [x] 更新模块 README，说明 CAS 使用方式和无 revision 实体边界。
- [x] 跑 build、schema validate、全量 entity-change regressions。已通过 `pnpm build`、`pnpm prisma validate`、revision guard regression 和全量 entity-change regression。
- [x] 更新本文档 `23.3 变更流水` 和 Phase 16 最终状态。

验收方式：

- Event 传入过期 revision 时返回 409。
- Event 无 revision 冲突时仍生成正常 diff/change log/archive。
- Brand 审核通过实际写库时，如果 revision 已变化，写库失败并返回 stale edit。
- 无 revision 实体不因本阶段改造出现破坏性 API 变更。
- 旧 publicChanges、summary、多语言 detail 不受影响。

### 23.3 变更流水

每次代码改动都必须新增一行。只改文档也要记录，方便回看设计演进。

| 日期 | 阶段 | 文件 | 变更摘要 | 验证 | 状态 |
| --- | --- | --- | --- | --- | --- |
| 2026-06-04 | Phase 0 | `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 新建设计文档，确认第一批范围、存储策略、推送旧值/新值、旧服务废弃策略 | `wc -l`、`rg` 检查关键决策 | Done |
| 2026-06-04 | Phase 0 | `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 新增分阶段 checklist、追踪规则、变更流水，作为后续改造唯一执行看板 | 人工复查章节结构 | Done |
| 2026-06-05 | Phase 0/1 | `server/prisma/schema.prisma`, `server/prisma/migrations/20260605103000_add_entity_change_logs/migration.sql`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 新增 `EntityChangeLog` Prisma model 与 `entity_change_logs` migration；记录旧 summary 调用点替换范围并锁定第一波实体边界 | `pnpm prisma:generate`, `pnpm prisma migrate deploy`, 事务写入后回滚检查 | Done |
| 2026-06-05 | Phase 1/2/3/4/5/6 | `server/src/modules/entity-change/**`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 新增 entity-change 核心模块、diff engine、summarizer、repository、registry，以及 event/dj/brand snapshot builders 和 configs | `pnpm prisma:generate`, `pnpm build` | Done |
| 2026-06-05 | Phase 4/5 | `server/src/controllers/event.controller.ts`, `server/src/controllers/dj.controller.ts`, `server/src/modules/entity-change/entity-change.service.ts`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 接入 Event/DJ 更新入口；Event 在现有更新流程前后 capture snapshot；DJ 改为 `trackUpdate` 并补 update 白名单；响应增加 `change` | `pnpm build` | Done |
| 2026-06-05 | Phase 6 | `server/src/services/content-submission-brand.service.ts`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | Brand content submission 实际 create/update `WikiFestival` 后生成并持久化 change log，create 使用 null before，update 使用 before/after snapshot | `pnpm build` | Done |
| 2026-06-05 | Phase 3/7 | `server/src/modules/entity-change/entity-change-diff-engine.ts`, `server/src/services/content-submission-processing.service.ts`, `server/src/services/content-submission-event.service.ts`, `server/src/routes/bff.web.routes.ts`, `server/src/routes/content-submission.routes.ts`, `server/src/scripts/backfill-contribution-module.ts`, `server/src/scripts/dj-edit-submission-regression.ts`, `server/src/services/content-submission-change-summary.service.ts`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 补 ordered-list diff；删除旧 payload 猜测式 summary 服务；移除生产 routes/services 和脚本中的旧 summary 调用 | `rg "content-submission-change-summary|changeSummaryTextFromPayload|attachContentSubmissionChangeSummary" server/src`, `pnpm build` | Done |
| 2026-06-05 | Phase 3 | `server/src/modules/entity-change/entity-change-diff-engine.ts`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | create/delete 场景从 root diff 改为递归字段 diff，避免 Brand create 只记录根节点新增 | `pnpm build` | Done |
| 2026-06-05 | Phase 1/9 | `server/prisma/schema.prisma`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 执行最终基础验证；schema 合法，旧 summary 搜索无结果；migration 实际应用因工作区存在其他未提交 migration 暂不执行 | `pnpm prisma validate`, `rg "content-submission-change-summary|changeSummaryTextFromPayload|attachContentSubmissionChangeSummary" server/src` | Done |
| 2026-06-05 | Phase 4/5/8 | `server/src/services/content-submission-event.service.ts`, `server/src/services/content-submission-dj.service.ts`, `server/src/modules/entity-change/entity-change.service.ts`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | Event/DJ content submission 实际入库路径生成 change log；`persistChange` 统一桥接 `AdminAuditLog.detail`，写入 `changeLogId`、hash、summary 和 private changes | `pnpm build` | Done |
| 2026-06-05 | Phase 8 | `server/src/services/content-submission-processing.service.ts`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | content submission approved 通知查询最新 entity change log，将 `changeLogId`、`publicSummaryZh`、`publicChanges` 写入 notification metadata，并在通知 body 追加 public summary | `pnpm build` | Done |
| 2026-06-05 | Phase 8 | `server/src/routes/notification-center.routes.ts`, `server/src/routes/bff.web.routes.ts`, `server/src/routes/content-submission.routes.ts`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | admin event/dj/brand 发布使用 latest change log 更新 body/metadata；BFF 与 content-submission review 创建的 `NotificationAdminContentHistory.payload` 写入 `changeLogId/publicChanges/publicSummaryZh`；route 字段保持 additive 兼容 | `pnpm build` | Done |
| 2026-06-05 | Phase 9 | `server/src/scripts/entity-change-event-regression.ts`, `server/src/scripts/entity-change-dj-regression.ts`, `server/src/scripts/entity-change-brand-regression.ts`, `server/package.json`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 新增 event/dj/brand entity-change regression scripts，并加入 package scripts；覆盖 Event keyed timetable diff、DJ set 数组语义、Brand aliases/city old/new | `pnpm build`, `pnpm ts-node src/scripts/entity-change-event-regression.ts`, `pnpm ts-node src/scripts/entity-change-dj-regression.ts`, `pnpm ts-node src/scripts/entity-change-brand-regression.ts` | Done |
| 2026-06-05 | Phase 9/10 | `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 执行收敛验证并更新最终追踪状态；旧 summary 搜索无结果，schema/build 通过；migration apply 和最终 diff 范围审阅保留为阻塞/待确认项 | `rg "content-submission-change-summary|changeSummaryTextFromPayload|attachContentSubmissionChangeSummary" server/src`, `pnpm prisma validate`, `pnpm build`, `git status --short` | Done |
| 2026-06-05 | Phase 9/10 | `server/src/scripts/entity-change-core-regression.ts`, `server/package.json`, `server/src/modules/entity-change/README.md`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 新增 core regression 覆盖 canonicalizer 和 diff engine；补 entity-change 模块 README，说明变更摘要来源、通知 publicChanges 规则和 MD 追踪纪律 | `pnpm build`, `pnpm ts-node src/scripts/entity-change-core-regression.ts` | Done |
| 2026-06-05 | Phase 1/9/10 | `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 最终非破坏性验证通过；只剩 migration 实际应用和全量 diff 范围审阅两个阻塞项，均因工作区存在其他未提交 migration/submodule 改动需单独确认 | `pnpm build`, `pnpm prisma validate`, `pnpm entity-change:core:regression`, `pnpm entity-change:event:regression`, `pnpm entity-change:dj:regression`, `pnpm entity-change:brand:regression`, `git status --short` | Done |
| 2026-06-05 | Phase 1/9/10 | `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 应用 `entity_change_logs` migration，完成事务写入后回滚验证；重新跑 schema/build/四个 regression；按 `docs`/`server` 范围完成最终 diff 复查，外部 submodule 脏状态保持未触碰 | `pnpm prisma migrate deploy`, `pnpm ts-node -e ...rollback...`, `pnpm prisma validate`, `pnpm build`, `pnpm entity-change:core:regression`, `pnpm entity-change:event:regression`, `pnpm entity-change:dj:regression`, `pnpm entity-change:brand:regression`, `git diff --name-status -- docs server` | Done |
| 2026-06-05 | Phase 11 | `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 启动第二阶段 `djSet` 扩展接入 checklist，明确 create/update/add tracks/replace tracks/delete 都统一调用 entity-change 领域服务 | `rg "Phase 11" docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | Done |
| 2026-06-05 | Phase 11 | `server/src/modules/entity-change/entity-change.types.ts`, `server/src/modules/entity-change/entity-change-summarizer.ts`, `server/src/modules/entity-change/entity-change-diff-engine.ts`, `server/src/modules/entity-change/index.ts`, `server/src/modules/entity-change/snapshots/dj-set.snapshot.ts`, `server/src/modules/entity-change/configs/dj-set.change-config.ts`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | entity-change 核心扩展 `djSet`；新增 DJSet snapshot/config/registry；tracks 使用 keyed-list by `position` identity，lineup 使用无序语义；增强 keyed-list 子字段 path config 命中 | `pnpm build`, `pnpm entity-change:dj-set:regression` | Done |
| 2026-06-05 | Phase 11 | `server/src/services/djset.service.ts`, `server/src/routes/djset.routes.ts`, `server/src/scripts/entity-change-dj-set-regression.ts`, `server/package.json`, `server/src/modules/entity-change/README.md`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | DJSet create/update/add tracks/batch tracks/replace tracks/delete 统一写入 entity-change log；API 响应 additive 返回 `change`；新增 djSet regression 和 README 第二阶段说明 | `pnpm prisma validate`, `pnpm build`, `pnpm entity-change:core:regression`, `pnpm entity-change:event:regression`, `pnpm entity-change:dj:regression`, `pnpm entity-change:brand:regression`, `pnpm entity-change:dj-set:regression` | Done |
| 2026-06-05 | Phase 11 | `server/src/services/djset.service.ts`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | DJSet delete 路径改为在同一 transaction 内 capture before snapshot 并删除，减少删除日志与实际删除之间的竞态窗口 | `pnpm build`, `pnpm entity-change:dj-set:regression` | Done |
| 2026-06-05 | Phase 12 | `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 将多语言 summary 英文/日文和 App 内修改详情页从未来扩展提升为 Phase 12 正式范围，补充数据库、API、iOS 页面与验收 checklist | `rg "Phase 12" docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | Done |
| 2026-06-05 | Phase 12 | `server/prisma/schema.prisma`, `server/prisma/migrations/20260605113000_add_entity_change_log_ja_summaries/migration.sql`, `server/src/modules/entity-change/**` | `EntityChangeLog` 增加 Ja summary 字段；summarizer 生成 zh/en/ja private/operator/public 摘要；repository 持久化 Ja；diff engine 输出 `labelJa/beforeJa/afterJa` 并提供日文字段标签兜底 | `pnpm prisma:generate`, `pnpm prisma validate`, `pnpm build`, `pnpm entity-change:core:regression` | Done |
| 2026-06-05 | Phase 12 | `server/src/routes/bff.routes.ts`, `server/src/services/content-submission-processing.service.ts`, `server/src/routes/notification-center.routes.ts`, `server/src/routes/bff.web.routes.ts`, `server/src/routes/content-submission.routes.ts` | 新增 `GET /v1/entity-change-logs/:id/public`，只返回 summaries 与 `publicChanges`；notification/history metadata 增加 `publicSummaryEn/publicSummaryJa` 并兼容旧 `publicSummaryZh` | `pnpm build`, `pnpm entity-change:core:regression` public detail payload 断言 | Done |
| 2026-06-05 | Phase 12 | `mobile/ios/RaverMVP/RaverMVP/Core/Models.swift`, `Core/SocialService.swift`, `Core/LiveSocialService.swift`, `Core/MockSocialService.swift`, `Features/Notifications/NotificationRepository.swift` | iOS 增加 `changeLogId`、`EntityChangeSummaryBundle`、`EntityChangePublicChange`、`EntityChangePublicDetail`；Live/Mock service 与 repository 增加公开修改详情拉取能力 | `xcodebuild -list -workspace RaverMVP.xcworkspace` | Done |
| 2026-06-05 | Phase 12 | `mobile/ios/RaverMVP/RaverMVP/Features/Notifications/EntityChangeDetailView.swift`, `Features/Notifications/NotificationsView.swift`, `Application/Coordinator/MainTabCoordinator.swift`, `RaverMVP.xcodeproj/project.pbxproj` | 新增 App 内“修改详情 / Change Details”页面，展示多语言 summary 和公开字段旧值/新值；通知点击携带 `changeLogId` 时优先进入详情页；新增页面加入 Xcode target Sources | `xcodebuild -list -workspace RaverMVP.xcworkspace`; `xcodebuild ... build` 已尝试但被外部 `_OpenAPIGeneratorCore` target 限制阻塞 | Done |
| 2026-06-05 | Phase 12 | `server/src/scripts/entity-change-core-regression.ts`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 更新 regression 覆盖英/日 summary、public detail payload 多语言字段，以及不暴露 private `changes`；完成 Phase 12 checklist 与最终流水记录 | `pnpm build`, `pnpm entity-change:core:regression`, `pnpm entity-change:event:regression`, `pnpm entity-change:dj:regression`, `pnpm entity-change:brand:regression`, `pnpm entity-change:dj-set:regression`, `git diff --check -- docs server mobile/ios/RaverMVP/RaverMVP mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` | Done |
| 2026-06-05 | Phase 13 | `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 启动 `news/post` 第三阶段接入 checklist，明确先覆盖审核通过后的 NewsArticle/Post create 路径和绑定关系 diff | `rg "Phase 13" docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | Done |
| 2026-06-05 | Phase 13 | `server/src/modules/entity-change/entity-change.types.ts`, `server/src/modules/entity-change/snapshots/news.snapshot.ts`, `server/src/modules/entity-change/snapshots/post.snapshot.ts`, `server/src/modules/entity-change/configs/news.change-config.ts`, `server/src/modules/entity-change/configs/post.change-config.ts`, `server/src/modules/entity-change/index.ts`, `server/src/modules/entity-change/entity-change-summarizer.ts`, `server/src/modules/entity-change/entity-change-diff-engine.ts` | entity-change 核心扩展 `news/post`；正文类字段使用 preview+hash，hash 保持 private；绑定关系使用 set 语义；summary 和日文字段标签支持 News/Post | `pnpm build`, `pnpm entity-change:news-post:regression` | Done |
| 2026-06-05 | Phase 13 | `server/src/routes/content-submission.routes.ts`, `server/src/services/content-submission-processing.service.ts`, `server/src/modules/entity-change/snapshots/snapshot-utils.ts`, `server/src/scripts/entity-change-news-post-regression.ts`, `server/package.json`, `server/src/modules/entity-change/README.md` | NewsArticle 和 ID/Post 审核通过创建路径写入 create change log；submission/status notification helper 支持 `news/post/djSet` change metadata；新增 news/post regression 与 README 第三阶段说明 | `pnpm prisma validate`, `pnpm build`, `pnpm entity-change:core:regression`, `pnpm entity-change:event:regression`, `pnpm entity-change:dj:regression`, `pnpm entity-change:brand:regression`, `pnpm entity-change:dj-set:regression`, `pnpm entity-change:news-post:regression` | Done |
| 2026-06-05 | Phase 14 | `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 启动 `label` 第四阶段接入 checklist，明确先覆盖审核通过后的 Label create 路径和厂牌资料 diff | `rg "Phase 14" docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | Done |
| 2026-06-05 | Phase 14 | `server/src/modules/entity-change/entity-change.types.ts`, `server/src/modules/entity-change/snapshots/label.snapshot.ts`, `server/src/modules/entity-change/configs/label.change-config.ts`, `server/src/modules/entity-change/index.ts`, `server/src/modules/entity-change/entity-change-summarizer.ts`, `server/src/modules/entity-change/entity-change-diff-engine.ts` | entity-change 核心扩展 `label`；新增厂牌资料 snapshot/config；genres 使用 set 语义；summary 和日文字段标签支持 Label | `pnpm build`, `pnpm entity-change:label:regression` | Done |
| 2026-06-05 | Phase 14 | `server/src/routes/content-submission.routes.ts`, `server/src/services/content-submission-processing.service.ts`, `server/src/scripts/entity-change-label-regression.ts`, `server/package.json`, `server/src/modules/entity-change/README.md` | Label 审核通过创建路径写入 create change log；submission/status notification helper 支持 `label` change metadata；新增 label regression 与 README 第四阶段说明 | `pnpm prisma validate`, `pnpm build`, `pnpm entity-change:core:regression`, `pnpm entity-change:event:regression`, `pnpm entity-change:dj:regression`, `pnpm entity-change:brand:regression`, `pnpm entity-change:dj-set:regression`, `pnpm entity-change:news-post:regression`, `pnpm entity-change:label:regression` | Done |
| 2026-06-05 | Phase 15 | `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 启动 Snapshot 短期归档与回滚基础 checklist，明确独立短期归档表不改变 `entity_change_logs` 长期隐私边界 | `rg "Phase 15" docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | Done |
| 2026-06-05 | Phase 15 | `server/prisma/schema.prisma`, `server/prisma/migrations/20260605143000_add_entity_change_snapshot_archives/migration.sql`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 新增 `EntityChangeSnapshotArchive` Prisma model 和 `entity_change_snapshot_archives` migration；归档表独立保存 before/after snapshot，带 `expires_at`、实体索引和 change log 级联关系 | `pnpm prisma:generate`, `pnpm prisma validate`, `pnpm prisma migrate deploy` | Done |
| 2026-06-05 | Phase 15 | `server/src/modules/entity-change/entity-change.types.ts`, `server/src/modules/entity-change/entity-change.repository.ts`, `server/src/modules/entity-change/entity-change.service.ts`, `server/src/controllers/event.controller.ts`, `server/src/services/content-submission-event.service.ts`, `server/src/services/content-submission-dj.service.ts`, `server/src/services/content-submission-brand.service.ts`, `server/src/routes/content-submission.routes.ts`, `server/src/services/djset.service.ts`, `server/src/scripts/entity-change-snapshot-archive-regression.ts`, `server/src/scripts/entity-change-snapshot-archive-cleanup.ts`, `server/package.json`, `server/src/modules/entity-change/README.md` | `persistChange` 支持 snapshots；repository 同事务写入短期 before/after archive；`trackUpdate` 与所有手动调用点传递 snapshots；新增归档 regression、过期清理脚本和 README 说明 | `rg "snapshots:\\s*\\{" server/src/controllers server/src/services server/src/routes server/src/modules -g '*.ts'`, `pnpm build`, `pnpm entity-change:snapshot-archive:regression` | Done |
| 2026-06-05 | Phase 15 | `server/src/scripts/entity-change-snapshot-archive-regression.ts`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 修正 snapshot archive regression 的 TypeScript assertion 收窄写法；完成 Phase 15 全量验证并同步最终 checklist | `pnpm prisma:generate`, `pnpm prisma validate`, `pnpm prisma migrate deploy`, `pnpm build`, `pnpm entity-change:snapshot-archive:regression`, `pnpm entity-change:snapshot-archive:cleanup`, `pnpm entity-change:core:regression`, `pnpm entity-change:event:regression`, `pnpm entity-change:dj:regression`, `pnpm entity-change:brand:regression`, `pnpm entity-change:dj-set:regression`, `pnpm entity-change:news-post:regression`, `pnpm entity-change:label:regression` | Done |
| 2026-06-05 | Phase 16 | `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 启动 Revision Compare-And-Swap 冲突检测 checklist，明确第一版强 CAS 范围为已有 revision 的 Event/Brand，无 revision 实体只保留扩展 hook | `rg "Phase 16" docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | Done |
| 2026-06-05 | Phase 16 | `server/src/modules/entity-change/entity-change-revision-guard.ts`, `server/src/modules/entity-change/entity-change.service.ts`, `server/src/modules/entity-change/index.ts`, `server/src/controllers/event.controller.ts`, `server/src/services/content-submission-brand.service.ts`, `server/src/scripts/entity-change-revision-guard-regression.ts`, `server/package.json`, `server/src/modules/entity-change/README.md`, `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 新增 revision guard；`trackUpdate` 支持 expectedRevision hook；Event update 支持 expected/base/revision 并使用 revision CAS；Brand 实际写库使用 revision CAS；新增 regression 和 README 说明 | `pnpm build`, `pnpm entity-change:revision-guard:regression` | Done |
| 2026-06-05 | Phase 16 | `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 完成 Phase 16 最终验证；compare-and-swap 从未来扩展移动到已落地范围 | `pnpm build`, `pnpm prisma validate`, `pnpm entity-change:revision-guard:regression`, `pnpm entity-change:core:regression`, `pnpm entity-change:event:regression`, `pnpm entity-change:dj:regression`, `pnpm entity-change:brand:regression`, `pnpm entity-change:dj-set:regression`, `pnpm entity-change:snapshot-archive:regression`, `pnpm entity-change:news-post:regression`, `pnpm entity-change:label:regression` | Done |
| 2026-06-05 | Phase 16 | `docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` | 收敛未来扩展文案，明确当前暂无下一阶段保留项，后续新增实体或回滚 UI 再开 Phase 17 | checklist 搜索无未完成项 | Done |

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

已从未来扩展提升并落地：

- `djSet`：曲目列表和视频元数据 diff，见 Phase 11。
- App 内“查看完整修改详情”页面，见 Phase 12。
- 多语言 summary：英文、日文，见 Phase 12。
- `news/post`：内容绑定和正文摘要 diff，见 Phase 13。
- `label`：厂牌资料 diff，见 Phase 14。
- Snapshot 短期归档与回滚基础：独立短期归档表、TTL 与清理脚本，见 Phase 15。
- 操作冲突检测：基于 revision 的 compare-and-swap，见 Phase 16。

当前暂未排入下一阶段的保留项：

- 暂无。后续新增实体或回滚 UI 需求出现时，再新增 Phase 17。

## 27. 最终结论

本方案的核心不是“写一个 deep diff 工具”，而是建立一个统一的内容变更领域服务：

- Snapshot builder 决定“什么是这个实体的业务状态”。
- Canonicalizer 决定“哪些结构等价”。
- Diff engine 决定“哪里变了”。
- Config 决定“数组语义、字段标签、可见性、安全性”。
- Summarizer 决定“用户和运营如何理解这次变化”。
- Repository 决定“审计和通知如何稳定追踪这次变化”。

第一批只接 `event`、`dj`、`brand`，但模块形态保持 registry 化。这样既能一步到位替换旧 summary，又不会把未来实体支持提前混进第一波实现里。
