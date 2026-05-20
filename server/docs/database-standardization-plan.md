# Raver 数据库关系标准化与 Lineup 最终改造方案

## 1. 结论先说

当前项目不是“彻底乱”，但已经出现了比较明显的关系层失真，主要集中在三类问题：

1. 多对多关系被 `TEXT[] / String[] / Json` 承载，关系事实没有落在标准关联表。
2. 同一业务事实被多张表重复存储，最典型的是 `event_lineup_slots`、`event_lineup_artists`、`event_timetable_slots`。
3. 读写逻辑围绕这些非标准关系做了大量兼容代码，导致查询路径、字段语义、命名体系逐渐分叉。

如果继续在现结构上叠加功能，后面最容易出现的问题是：

- 绑定关系不同步
- 反向查询越来越慢、越来越难维护
- 同一页面不同接口返回不一致
- 迁移成本随时间指数上升

这份方案的目标不是“把所有数组和 JSON 都消灭”，而是做两件事：

1. 把**关系事实**全部收回到标准关系表。
2. 把数组/JSON 只保留给**快照、配置、展示、多语言、缓存**这类天然非关系数据。

---

## 2. 本次核验范围

本次核验覆盖：

- `server/prisma/schema.prisma`
- `server/prisma/migrations/*`
- `server/src/routes/*`
- `server/src/controllers/*`
- `server/src/services/*`

重点检查了四类风险：

1. 主表数组 ID / JSON ID 关联
2. 双向列表查询是否依赖数组 `has/hasSome`
3. 关联事实是否重复存储
4. 列表接口是否存在内存排序 / 内存分页

---

## 3. 总体判断

### 3.1 已经做得比较规范的部分

- 一对多外键整体不差，例如：
  - `DJSet.djId`
  - `DJSet.eventId`
  - `RatingEvent.sourceEventId`
  - `Comment.setId`
- 用户行为表大体是对的：
  - `post_likes`
  - `post_saves`
  - `post_reposts`
  - `post_shares`
  - `post_hides`
- 许多普通分页接口已经使用了 SQL `orderBy + take/skip`

### 3.2 当前最乱的地方

- `Event ↔ DJ` 的事实被拆散在 3 张表里
- `Post / News` 的绑定关系用数组字段承载
- `Follow / Favorite / Preference` 的语义没有统一
- `brand`、`wikiFestival`、`label`、`festival` 概念混用
- 同一套 lineup 归一化逻辑在多个入口重复实现

---

## 4. 需要标准化的关系清单

下面按“是否应该改”为标准关系表来划分。

## 4.1 必须改造

### A. 用户关注 / 收藏 / 偏好

#### 当前现状

- `users.favorite_dj_ids`
- `users.favorite_genres`
- `follows`
- `event_favorites`

#### 问题

- 同样是“用户和目标实体的关系”，现在被拆成了 3 种模型：
  - 数组
  - `Follow`
  - `EventFavorite`
- `Follow` 结构也不统一，同时有 `followingId` 和 `djId`
- `favoriteGenres` 还是字符串，不是稳定实体 ID

#### 最终建议

建立统一的用户目标关系表，替代 `Follow + EventFavorite + favoriteDjIds`：

- `user_entity_follows`
  - `id`
  - `user_id`
  - `target_type`，如 `user | dj | event | festival_brand | label | genre`
  - `target_id`
  - `relation_type`，如 `follow | favorite | subscribe`
  - `sort_order`
  - `created_at`

建议索引：

- `(user_id, relation_type, target_type, created_at desc)`
- `(target_type, target_id, relation_type, created_at desc)`
- 唯一键 `(user_id, relation_type, target_type, target_id)`

备注：

- 如果你坚持“关注一律一张表且不用 relation_type”，也可以把 `event favorite` 直接视为 `follow`。
- `favoriteGenres` 如果是“推荐偏好”而不是“公开关注”，也可以单独拆成：
  - `user_genre_preferences`

---

### B. Post / News 与 DJ / Event / FestivalBrand 的绑定

#### 当前现状

- `posts.bound_dj_ids`
- `posts.bound_brand_ids`
- `posts.bound_event_ids`
- `news_articles.bound_dj_ids`
- `news_articles.bound_brand_ids`
- `news_articles.bound_event_ids`

#### 问题

- 典型的多对多关系存在数组字段中
- 反向查询依赖 `has / hasSome`
- 不符合“所有双向查询走关联表”的标准

#### 最终建议

按关系分别拆表，不要做一个混合型万能绑定表：

- `post_dj_bindings`
- `post_event_bindings`
- `post_festival_brand_bindings`
- `news_dj_bindings`
- `news_event_bindings`
- `news_festival_brand_bindings`

标准字段建议：

- `id`
- 主体 ID
- 目标 ID
- `binding_type`
- `sort_order`
- `created_at`

标准索引建议：

- `(post_id, sort_order, created_at)`
- `(dj_id, created_at)`
- `(event_id, created_at)`
- `(festival_brand_id, created_at)`
- 唯一键 `(post_id, dj_id)` / `(article_id, event_id)` 这类组合唯一

说明：

- 这里不建议用一个 `content_entity_bindings` 大表，因为你自己的约束已经明确反对“多类不同绑定关系强行塞同一张中间表”。

---

### C. Event ↔ DJ 以及整套 Lineup / Timetable

#### 当前现状

当前有 3 张相关表：

- `event_lineup_slots`
- `event_lineup_artists`
- `event_timetable_slots`

其中都在重复存以下信息的一部分：

- `event_id`
- `dj_id`
- `dj_ids`
- `dj_name`
- `festival_day_index`
- `stage_name`
- `sort_order`
- `start_time`
- `end_time`

#### 问题本质

这 3 张表现在分别在扮演以下角色，但边界不清：

- `event_lineup_artists`：像“活动阵容名单”
- `event_timetable_slots`：像“时间表演出场次”
- `event_lineup_slots`：本质上也是“时间表演出场次”，和上面高度重复

最关键的问题有 4 个：

1. 同一个业务事实被重复存两遍甚至三遍。
2. 多 DJ 关系仍然靠 `dj_ids` 数组，不是关系表。
3. `stage_name` 只是字符串，`stage_order` 却在 `events.stage_order` JSON 里，舞台没有正式实体。
4. DJ 反查 Event 的时候，依然要扫 slot 表和数组字段。

#### 最终成熟方案

这部分建议采用**事件阵容实体 + 阵容成员表 + 演出场次表 + 舞台表**的四层模型。

保留“阵容”和“场次”两个层次，但只保留一个事实来源，不重复。

#### 最终表设计

1. `event_artists`

- 一个活动维度下的“阵容单元”
- 表示海报上的一个 act，不一定有时间表
- 例如：
  - `Skrillex`
  - `Illenium`
  - `A B2B B`
  - `Secret Guest`

字段建议：

- `id`
- `event_id`
- `display_name`
- `normalized_name`
- `act_type`，如 `solo | b2b | b3b | live | group | host | unknown`
- `primary_dj_id`，可空
- `billing_order`
- `poster_tier`
- `source_type`
- `is_timetable_only`
- `created_at`
- `updated_at`

索引建议：

- `(event_id, billing_order)`
- `(event_id, normalized_name)`
- `(primary_dj_id)`

2. `event_artist_members`

- 一个阵容单元下的成员列表
- 用它解决 `dj_ids` 数组问题
- 对 B2B / 多人组合尤其关键

字段建议：

- `id`
- `event_artist_id`
- `dj_id`，可空
- `member_name_snapshot`
- `member_order`
- `role`
- `created_at`

索引建议：

- `(event_artist_id, member_order)`
- `(dj_id, event_artist_id)`
- 唯一键 `(event_artist_id, member_order)`

说明：

- `dj_id` 允许为空，这样未匹配到库内 DJ 的成员也能落库。
- `member_name_snapshot` 解决“只认名字但暂时没匹配 DJ”的问题。

3. `event_stages`

- 不再把舞台顺序存在 `events.stage_order` JSON
- 正式建立活动舞台实体

字段建议：

- `id`
- `event_id`
- `name`
- `normalized_name`
- `sort_order`
- `created_at`

索引建议：

- `(event_id, sort_order)`
- `(event_id, normalized_name)`
- 唯一键 `(event_id, normalized_name)`

4. `event_performances`

- 这是唯一的时间事实表
- 用来替代 `event_timetable_slots`，同时淘汰 `event_lineup_slots`

字段建议：

- `id`
- `event_id`
- `event_artist_id`
- `stage_id`，可空
- `display_name_snapshot`
- `festival_day_index`
- `start_at`
- `end_at`
- `sort_order`
- `status`
- `source_type`
- `created_at`
- `updated_at`

索引建议：

- `(event_id, start_at)`
- `(event_id, festival_day_index, start_at)`
- `(stage_id, start_at)`
- `(event_artist_id, start_at)`

#### 为什么这是最合适、最高效、最成熟的方案

因为它把 3 件本来就不同的业务事实彻底分开了：

1. **谁在这个活动阵容里**：`event_artists`
2. **这个阵容由哪些 DJ 构成**：`event_artist_members`
3. **这个阵容什么时候在哪个舞台演**：`event_performances`

这比当前结构成熟的地方在于：

- 不会再出现 slot 表和 timetable 表互相镜像
- B2B / 多人 act 有规范归属，不再依赖 `dj_ids`
- 海报阵容和时间表能共存，但不重复
- 舞台变成正式实体，排序、扩展、统计都更稳
- DJ 反查活动、活动反查 DJ、活动反查时间表，都能走标准索引

#### 这部分最终要废弃什么

- `event_lineup_slots`
- `event_timetable_slots`
- `event_lineup_artists.dj_ids`
- `event_timetable_slots.dj_ids`
- `event_lineup_slots.dj_ids`
- `events.stage_order` JSON

其中：

- `event_lineup_artists` 可以不直接删表，但建议迁移后重建成新的 `event_artists`
- 如果不想大改表名，也可以保留表名 `event_lineup_artists`，但字段和职责必须按新模型重构

---

### D. DJSet ↔ DJ / Event

#### 当前现状

- `dj_sets.dj_id`
- `dj_sets.co_dj_ids`
- `dj_sets.event_id`

#### 问题

- 多 DJ 关系仍然是数组
- Event 关系当前是单外键，只能表达“主归属活动”
- 如果未来要支持“同一个 set 同时关联多个活动页 / 多场演出 / 多个品牌专题”，现结构不够

#### 最终建议

1. DJ 关系：

- 保留 `primary_dj_id`
- 新增 `dj_set_artists`

字段建议：

- `id`
- `set_id`
- `dj_id`，可空
- `artist_name_snapshot`
- `artist_order`
- `role`
- `created_at`

2. Event 关系：

- 如果业务上“一个 set 只天然归属一个 event”，保留 `primary_event_id`
- 如果业务上需要多活动绑定，再新增：
  - `event_set_bindings`

这会比直接把 `event_id` 改成多对多更成熟，因为：

- 既保留主归属
- 又支持扩展绑定
- 查询和后台运营都更清晰

---

### E. RatingUnit ↔ DJ

#### 当前现状

- `rating_units.dj_id`
- `rating_units.dj_ids`

#### 问题

- 这是明显的多 DJ 评分单元
- 仍然用数组保存

#### 最终建议

建立：

- `rating_unit_dj_bindings`

字段建议：

- `id`
- `unit_id`
- `dj_id`
- `sort_order`
- `binding_type`
- `created_at`

索引建议：

- `(unit_id, sort_order)`
- `(dj_id, created_at)`
- 唯一键 `(unit_id, dj_id)`

是否保留 `rating_units.dj_id`：

- 可以保留 `primary_dj_id` 作为主展示字段
- 但 `dj_ids` 数组必须废弃

---

### F. DJ ↔ Genre

#### 当前现状

- `djs.genres` 是字符串数组
- `genres.key_artists` / `key_artist_bindings` 也混合了展示与关系

#### 问题

- DJ 和 Genre 都是一级实体，但两边关系没有标准表
- `favoriteGenres`、`label.genres`、`dj.genres` 用的还不是同一种语义

#### 最终建议

最终可以建立：

- `dj_genre_bindings`
- 可选：`label_genre_bindings`
- 可选：`user_genre_preferences`

当前执行决策：

- 本轮 `djs.genres` 继续保持字符串数组，作为展示快照使用。
- 本轮不把 `djs.genres` 自动匹配到 `genres.id`。
- 本轮不切 DJ 详情 genre 读写。
- 后续需要支持“点击 genre 跳转到 genre 介绍页”时，再设计明确的 genre alias / mapping 规则，然后迁移到 `dj_genre_bindings`。

`Genre.key_artists` 的最终建议：

- `key_artists` 作为展示快照可保留一段时间
- 但关系事实改为：
  - `genre_key_dj_bindings`

如果“关键艺术家”本质上只是一个专题展示配置，也可以保留为：

- `genre_featured_artists`

总之不要继续让 `keyArtistBindings Json` 承担正式关系职责。

---

### G. SquadActivity.participants

#### 当前现状

- `squad_activities.participants` 是 `String[]`
- 同时你在 `SquadOfflineActivity` 已经有标准化的 `SquadOfflineActivityParticipant`

#### 问题

- 同一套“活动参与人”概念，在一个地方是数组，在另一个地方是关系表
- 这会让模型风格越来越不统一

#### 最终建议

建立：

- `squad_activity_participants`

字段建议：

- `id`
- `activity_id`
- `user_id`
- `joined_at`
- `left_at`
- `status`

这样能和 `SquadOfflineActivityParticipant` 统一思路。

---

### H. UserVirtualAssetEquip.asset_ids

#### 当前现状

- `user_virtual_asset_equips.asset_ids` 是数组

#### 判断

这不是最高优先级，但如果你要追求结构一致性，它也属于“关系事实混在数组里”。

#### 最终建议

如果一个装备位理论上可以装备多个资产，建议拆成：

- `user_virtual_asset_equip_items`

字段建议：

- `id`
- `user_id`
- `asset_type`
- `asset_id`
- `equip_order`
- `created_at`

如果一个装备位理论上只能装备一个资产，那更简单：

- 直接把 `asset_ids` 改成 `asset_id`

---

## 4.2 可以保留，不必关系化

下面这些不建议为了“形式统一”强行拆表：

- i18n JSON
  - `nameI18n`
  - `descriptionI18n`
  - `countryI18n`
  - `cityI18n`
- 地理/配置类 JSON
  - `manualLocation`
  - `locationPoint`
  - `socialLinks`
  - `contacts`
  - `linksInWeb`
- 展示或导入快照
  - `sourceGenres`
  - `sourceLabels`
  - `sourceSameAs`
  - `customDjNames`
  - `referenceLinks`
- 纯缓存 / 推荐结果快照
  - `user_daily_event_recommendations.activity_ids`
  - `user_daily_dj_recommendations.dj_ids`

规则很简单：

- 如果它是“正式关系事实”，必须拆表。
- 如果它是“快照、配置、展示、多语言、导入原文”，可以保留数组/JSON。

---

## 5. 数据库层当前最需要纠正的命名和语义漂移

## 5.1 `brand` 和 `wikiFestival` 语义混用

当前代码里 `boundBrandIds` 很多时候实际指向的是 `wikiFestival`，而不是音乐厂牌 `label`。

这是一个长期风险点，因为你系统里已经同时有：

- `Event`
- `WikiFestival`
- `Label`

建议最终明确三种实体：

- `Event`：某次具体活动
- `FestivalBrand`：活动品牌 / 系列 IP
- `Label`：音乐厂牌

短期建议：

- DB 可先不重命名 `wiki_festivals`
- 但 API / service / binding 表命名改成 `festivalBrand`

例如：

- `boundBrandIds` -> `boundFestivalBrandIds`
- `post_festival_brand_bindings`
- `news_festival_brand_bindings`

---

## 5.2 旧结构和新结构并存，没有真正完成替换

最典型的是：

- 先有 `event_lineup_slots`
- 后来又加了 `event_lineup_artists` 和 `event_timetable_slots`
- 但没有让旧表退出事实层

这类“只增不退”的演进方式，短期快，长期一定乱。

当前已确认：本次迁移窗口内不会产生新数据。因此本次不采用“双写 + 渐进切读”的策略，而采用：

1. 冻结写入口和后台任务
2. 一次性建立完整 canonical 新结构
3. 一次性全量迁移旧数据
4. 一次性校验新旧数据一致性
5. 一次性切换业务读写到新结构
6. 旧结构只读保留一段观察期
7. 稳定后删除旧字段 / 旧表

这条路线的核心前提是：迁移开始后旧表不再产生新增、修改、删除数据。如果这个前提未来发生变化，必须回到“双写 / 增量补偿”策略。

---

## 5.3 相同归一化逻辑重复出现在多个入口

`lineup` 相关的归一化逻辑现在至少出现在：

- `server/src/controllers/event.controller.ts`
- `server/src/routes/bff.web.routes.ts`

这意味着：

- 未来一旦改模型，要改很多地方
- 很容易出现一个入口更新了，另一个入口没更新

最终建议：

- 抽成单独的 `event-lineup-domain.service.ts`
- 所有 create/update/query 都只调同一套 domain service

---

## 6. 最终推荐的目标数据模型

## 6.1 Canonical 层

这一层只存正式关系事实。

### 用户关系

- `user_entity_follows`
- `user_genre_preferences` 可选

### 内容绑定

- `post_dj_bindings`
- `post_event_bindings`
- `post_festival_brand_bindings`
- `news_dj_bindings`
- `news_event_bindings`
- `news_festival_brand_bindings`

### Event / Lineup / Timetable

- `event_artists`
- `event_artist_members`
- `event_stages`
- `event_performances`

### DJSet

- `dj_set_artists`
- `event_set_bindings` 可选

### Rating

- `rating_unit_dj_bindings`

### Genre

- `dj_genre_bindings`
- `label_genre_bindings` 可选
- `genre_featured_artists` 或 `genre_key_dj_bindings`

### 其他关系

- `squad_activity_participants`
- `user_virtual_asset_equip_items`

---

## 6.2 Snapshot / Cache / Config 层

这一层允许数组和 JSON，但绝不作为正式关系源头。

- 多语言 JSON
- 地图 JSON
- 导入原始字段
- 推荐结果快照
- 展示型字符串数组

---

## 7. Lineup 最终方案：我建议你怎么定版

这是整份方案里最关键的一部分。

## 7.1 最终拍板建议

最终以这套结构为准：

- `event_artists`
- `event_artist_members`
- `event_stages`
- `event_performances`

并执行以下决策：

1. `event_lineup_slots` 彻底退役
2. `event_timetable_slots` 的职责并入 `event_performances`
3. `event_lineup_artists` 升级为新的 `event_artists`
4. `dj_ids` 全部改成成员关联表
5. `stage_order` JSON 改成 `event_stages`

## 7.2 为什么不建议只保留 `event_timetable_slots`

如果你只保留时间表 slot 表，会有两个问题：

1. 海报阵容但没有排时间的 act 无法优雅表达
2. B2B / Group / Secret Guest 这种 act 的身份层会越来越难看

所以需要 `event_artists` 作为“阵容层”。

## 7.3 为什么不建议只保留 `event_lineup_artists`

因为只有阵容没有场次，时间表仍然要靠 JSON 或子字段补出来，最终又会回到现在这类混乱状态。

所以必须单独有 `event_performances`。

## 7.4 最成熟的职责边界

### `event_artists`

解决“这个活动有哪些 act”

### `event_artist_members`

解决“这个 act 由哪些 DJ 构成”

### `event_stages`

解决“这个活动有哪些舞台，以及顺序”

### `event_performances`

解决“这个 act 在什么时间、什么舞台演”

这套边界是清楚的，能长期扩展：

- 增加舞台地图
- 增加冲突检测
- 增加 timetable 版本
- 增加 performer role
- 增加演出取消 / 变更状态

都不需要再推翻模型。

---

## 8. 当前迁移策略：冻结写入后一次性切换

本次采用“完整新结构一次落地 + 旧数据一次性全量迁移 + 校验通过后一次性切换”的路线。

这不是渐进双写方案。它成立的前提是：迁移窗口内不会产生新数据，且所有会写旧表的入口都能被临时关闭。

### 8.1 核心路线

- [x] 确认迁移窗口内没有用户写入、后台导入、定时任务、管理端保存、脚本补数据。
- [x] 先建立完整 canonical 新表，不删除旧表和旧字段。
- [ ] 对旧库做全量备份，记录备份文件、时间、数据库版本、迁移负责人。
- [x] 一次性把旧表数据全量迁移到新表。
- [x] 用自动校验脚本确认新旧数据一致。
- [x] 校验通过后，一次性把业务读写切到新表。
- [ ] 旧表进入只读观察期。
- [ ] 稳定后删除旧字段和旧表。

### 8.2 本次不做的事情

- [x] 不做长期双写。
- [x] 不做按流量灰度切读。
- [x] 不继续维护 `*_ids` 数组关系字段。
- [x] 不继续往 `event_lineup_slots` 叠功能。
- [ ] 不把不同业务关系塞进一个万能 binding 大表。

---

## 9. 可落地执行清单

下面每一项都可以直接作为改造进度 checkbox 使用。顺序不要随意打乱，核心路线始终是：**先定模，再建表，再全量迁移，再校验，再切代码，再清旧结构**。

## Phase 0. 迁移前冻结和基线确认

### 0.1 写入冻结

- [ ] 暂停后台导入活动 / DJ / News / Post 的脚本。
- [ ] 暂停会写 `event_lineup_*`、`event_timetable_slots`、`posts.bound_*_ids`、`news_articles.bound_*_ids` 的管理端操作。
- [ ] 暂停会写 `follows`、`event_favorites`、`users.favorite_dj_ids` 的用户侧入口。
- [ ] 暂停会写 `dj_sets.co_dj_ids`、`rating_units.dj_ids`、`djs.genres` 的后台任务或导入脚本。
- [ ] 暂停通知统计、推荐生成、数据修复类定时任务，避免迁移期间写旧结构。
- [ ] 在数据库层确认关键旧表迁移前行数，记录为迁移基线。

### 0.2 命名和边界冻结

- [x] 冻结 `Event / Lineup / Timetable` 最终模型：`event_artists + event_artist_members + event_stages + event_performances`。
- [x] 冻结内容绑定模型：`post_*_bindings`、`news_*_bindings` 分表，不建万能混合表。
- [x] 冻结用户关系模型：`user_entity_follows` 作为关注 / 收藏 / 订阅统一入口。
- [x] 冻结 `brand` 语义：新表命名使用 `festival_brand`，短期仍可映射旧 `wiki_festivals`。
- [x] 冻结数组关系字段：不再新增 `*_ids` 关系数组。
- [x] 冻结 JSON 外键集合：不再新增承载正式关系的 JSON 字段。

### 0.3 备份和回滚准备

- [ ] 执行迁移前全量数据库备份。
- [ ] 保存备份恢复命令和恢复验证步骤。
- [x] 记录当前 Git commit / 分支 / Prisma migration 状态。
- [x] 记录当前旧表行数、关键索引、约束信息。
- [ ] 准备回滚方案：如果切换后失败，业务代码回退到旧结构，旧表仍保留原始数据。

---

## Phase 1. 一次性建立完整新表

### 1.1 必建 canonical 表

- [x] 新增 `user_entity_follows`。
- [x] 新增 `post_dj_bindings`。
- [x] 新增 `post_event_bindings`。
- [x] 新增 `post_festival_brand_bindings`。
- [x] 新增 `news_dj_bindings`。
- [x] 新增 `news_event_bindings`。
- [x] 新增 `news_festival_brand_bindings`。
- [x] 新增 `event_artists`。
- [x] 新增 `event_artist_members`。
- [x] 新增 `event_stages`。
- [x] 新增 `event_performances`。
- [x] 新增 `dj_set_artists`。
- [x] 新增 `rating_unit_dj_bindings`。
- [x] 新增 `dj_genre_bindings`。
  - 说明：本轮只预留表结构，不从 `djs.genres` 自动写入数据。

### 1.2 第二批可选表

- [ ] 视业务确认是否新增 `event_set_bindings`。
- [x] 视业务确认是否新增 `user_genre_preferences`。
- [ ] 视业务确认是否新增 `label_genre_bindings`。
- [ ] 视业务确认是否新增 `genre_featured_artists` 或 `genre_key_dj_bindings`。
- [ ] 视业务确认是否新增 `squad_activity_participants`。
- [ ] 视业务确认是否新增 `user_virtual_asset_equip_items`。

### 1.3 建表验收

- [x] 所有关联表都有主键。
- [x] 所有关联表都有反向查询索引。
- [x] 所有去重关系都有组合唯一约束。
- [x] 所有外键删除策略明确：核心父表删除走 `cascade`，目标实体删除通常走 `set null` 或 `cascade`，按业务语义确认。
- [x] Prisma schema 能生成 client。
- [x] 新 migration 能在空库执行成功。
- [x] 新 migration 能在当前库执行成功。

---

## Phase 2. 一次性全量迁移数据

### 2.1 内容绑定迁移

- [x] 从 `posts.bound_dj_ids` 全量生成 `post_dj_bindings`。
- [x] 从 `posts.bound_event_ids` 全量生成 `post_event_bindings`。
- [x] 从 `posts.bound_brand_ids` 全量生成 `post_festival_brand_bindings`。
- [x] 从 `news_articles.bound_dj_ids` 全量生成 `news_dj_bindings`。
- [x] 从 `news_articles.bound_event_ids` 全量生成 `news_event_bindings`。
- [x] 从 `news_articles.bound_brand_ids` 全量生成 `news_festival_brand_bindings`。
- [x] 对数组中的重复 ID 做去重，保留第一次出现的顺序作为 `sort_order`。
- [x] 对不存在的目标 ID 记录迁移异常日志，不静默丢弃。

### 2.2 用户关系迁移

- [x] 从 `follows.following_id` 迁移用户关注用户关系到 `user_entity_follows`。
- [x] 从 `follows.dj_id` 迁移用户关注 DJ 关系到 `user_entity_follows`。
- [x] 从 `event_favorites` 迁移活动收藏关系到 `user_entity_follows`。
- [x] 从 `users.favorite_dj_ids` 迁移 DJ 收藏或关注关系到 `user_entity_follows`。
- [x] 确认 `favorite_genres` 是推荐偏好还是公开关系；如果是偏好，迁移到 `user_genre_preferences`，否则迁移到 `user_entity_follows`。
- [x] 对同一用户、同一目标、同一关系类型做去重。

### 2.3 Lineup / Timetable 迁移

- [x] 从 `event_lineup_artists` 生成 `event_artists`。
- [x] 从 `event_lineup_artists.dj_name` 生成 `event_artists.display_name`。
- [x] 从 `event_lineup_artists.sort_order` 生成 `event_artists.billing_order`。
- [x] 从 `event_lineup_artists.dj_id` 生成 `event_artists.primary_dj_id`。
- [x] 从 `event_lineup_artists.dj_id + dj_ids` 生成 `event_artist_members`。
- [x] 对只有名字但没有 DJ ID 的成员写入 `member_name_snapshot`，`dj_id` 留空。
- [x] 从 `events.stage_order` 生成基础 `event_stages`。
- [x] 从 `event_timetable_slots.stage_name` 补齐 `event_stages`。
- [x] 从 `event_lineup_slots.stage_name` 补齐 `event_stages`。
- [x] 从 `event_timetable_slots` 生成 `event_performances`，它是时间事实的优先来源。
- [x] 对没有 timetable 但存在 `event_lineup_slots` 的数据，用 `event_lineup_slots` 补充 `event_performances`。
- [x] 对没有时间表但存在阵容的 act，只保留 `event_artists`，不强行生成 performance。
- [x] 如果 slot 找不到对应 `event_artist`，按 `event_id + normalized_name` 创建 `is_timetable_only = true` 的 `event_artist`。
- [x] 迁移后确认 `event_performances` 不再依赖任何 `dj_ids` 数组。

### 2.4 DJSet / Rating 迁移

- [x] 从 `dj_sets.dj_id` 生成 `dj_set_artists` 的主 DJ 记录。
- [x] 从 `dj_sets.co_dj_ids` 生成 `dj_set_artists` 的协作 DJ 记录。
- [x] 从 `dj_sets.custom_dj_names` 生成没有 `dj_id` 的 `dj_set_artists` 快照记录。
- [x] 从 `rating_units.dj_id` 生成 `rating_unit_dj_bindings` 主绑定记录。
- [x] 从 `rating_units.dj_ids` 生成 `rating_unit_dj_bindings` 多 DJ 绑定记录。
- [x] 本轮不迁移 `djs.genres`，继续保留为展示快照。

### 2.5 迁移日志

- [x] 每类迁移输出源表数量、目标表数量、跳过数量、异常数量。
- [x] 每类迁移输出异常明细文件或数据库迁移日志表。
- [x] 每类迁移脚本支持重复执行且不会重复插入数据。
- [x] 迁移脚本执行完成后记录执行时间和版本。

---

## Phase 3. 数据一致性校验

### 3.1 数量校验

- [x] `posts.bound_dj_ids` 展开后的数量 = `post_dj_bindings` 数量。
- [x] `posts.bound_event_ids` 展开后的数量 = `post_event_bindings` 数量。
- [x] `posts.bound_brand_ids` 展开后的数量 = `post_festival_brand_bindings` 数量。
- [x] `news_articles.bound_*_ids` 展开后的数量 = 对应 `news_*_bindings` 数量。
- [x] `follows + event_favorites + favorite_dj_ids` 展开去重后的数量 = `user_entity_follows` 对应数量。
- [x] 旧 lineup artist 数量能够被 `event_artists` 覆盖。
- [x] 旧 timetable / lineup slot 时间事实数量能够被 `event_performances` 覆盖。
- [x] `rating_units.dj_id + dj_ids` 展开去重后的数量 = `rating_unit_dj_bindings` 数量。
- [x] `dj_sets.dj_id + co_dj_ids + custom_dj_names` 展开后的数量 = `dj_set_artists` 数量。

### 3.2 关键字段校验

- [x] 每个 post 的 DJ / Event / FestivalBrand 绑定集合和旧数组一致。
- [x] 每篇 news 的 DJ / Event / FestivalBrand 绑定集合和旧数组一致。
- [x] 每个 event 的 artist 名称、排序、主 DJ 和旧 `event_lineup_artists` 一致。
- [x] 每个 event 的 stage 名称和排序能覆盖旧 `stage_order` 与 slot `stage_name`。
- [x] 每个 timetable slot 的时间、舞台、名称能在 `event_performances` 找到对应记录。
- [x] 每个 rating unit 的 DJ 集合和旧 `dj_id + dj_ids` 一致。
- [x] 每个 DJ set 的 DJ 集合和旧 `dj_id + co_dj_ids + custom_dj_names` 一致。

### 3.3 抽样校验

- [x] 随机抽样 20 个 event，对比旧 lineup / timetable 和新结构返回结果。
- [x] 随机抽样 20 个 DJ，对比 DJ 反查活动、set、rating 的结果。
- [x] 随机抽样 20 个 post，对比绑定实体。
- [x] 随机抽样 20 篇 news，对比绑定实体。
- [x] 随机抽样 20 个用户，对比关注、收藏、偏好结果。

### 3.4 校验通过标准

- [x] 阻断级错误数量为 0。
- [x] 可解释异常都有记录和处理结论。
- [x] 校验脚本输出保存到迁移记录中。
- [x] 负责人确认可以进入业务切换。

---

## Phase 4. 一次性切换业务代码

### 4.1 Lineup 读写切换

- [x] Event 详情页改读 `event_artists + event_artist_members + event_stages + event_performances`。
- [x] BFF Web `/events/:id/lineup` 列表改读 canonical lineup。
- [x] Event 创建 / 编辑改写新 lineup 结构。
  - [x] BFF Web `/events` 创建 / 编辑已在同一事务内写入 `event_artists + event_artist_members + event_stages + event_performances`。
  - [x] Event controller `/api/events` 创建 / 编辑接入 canonical 写入。
- [x] Lineup / Timetable 局部增删改接口已在旧兼容写入后重建 canonical 结构，保持 Event 详情读源一致。
- [x] DJ 详情页活动反查改走 `event_artist_members` / `event_performances`。
- [x] BFF Web 中旧 lineup 归一化逻辑移到统一 domain service。
- [x] Event controller 中重复 lineup 归一化逻辑改用同一 domain service。
- [x] 不再写 `event_lineup_slots`。
- [x] 不再写 `event_timetable_slots.dj_ids`。
- [x] 不再写 `event_lineup_artists.dj_ids`。

### 4.2 Post / News 绑定切换

- [x] Post 创建 / 编辑改写 `post_*_bindings`。
- [x] Post 主要列表和详情改从 binding 表返回绑定 ID，旧数组仅作兼容回退。
- [x] News 创建改写 `news_*_bindings`。
- [x] News 列表、详情、搜索改从 binding 表返回绑定 ID，旧数组仅作兼容回退。
- [x] 关注 DJ / FestivalBrand 的动态统计改走 binding 表。
- [x] bound news feed 改走 binding 表。
- [x] 不再读写 `posts.bound_*_ids`。
- [x] 不再读写 `news_articles.bound_*_ids`。
- [ ] 请求层不再接受 legacy payload key：
  - [ ] `bound_dj_ids`
  - [ ] `bound_brand_ids`
  - [ ] `bound_event_ids`
  - [ ] `boundDjIds` / `boundBrandIds` / `boundEventIds` 小驼峰兼容别名
- [ ] 返回层不再保留任何“旧数组字段回退”逻辑，运行时只认 binding 表。

### 4.3 Follow / Favorite / Preference 切换

- [x] 用户关注用户改读写 `user_entity_follows`。
  - [x] 移动端 BFF `/social/users/:id/follow` 已切为只读写 `user_entity_follows`，不再双写旧 `follows`。
  - [x] App BFF `profile / users/:id / followers / following / friends / feed following` 已读新表。
- [x] 用户关注 DJ 改读写 `user_entity_follows`。
  - [x] BFF Web DJ follow/status/detail/followed 列表已切为只读写 `user_entity_follows`，不再双写旧 `follows`。
  - [x] App BFF feed 推荐召回中的 followed author / followed dj 候选已读新表。
  - [x] BFF Web DJ list / recommendations 的 follow 状态已读新表。
  - [x] 旧 `/api/follows` DJ follow/status/list 已切为只读写 `user_entity_follows`，不再双写旧 `follows`。
- [x] Event favorite 改读写 `user_entity_follows`。
  - [x] BFF Web Event favorite/status/list 已切为只读写 `user_entity_follows`，不再双写旧 `event_favorites`。
  - [x] 通知中心 event countdown / daily digest / marked event candidate 查询已读新表。
- [x] 用户 favorite DJ 改读写 `user_entity_follows` 或最终确认的 preference 表。
  - [x] `auth.controller.ts` profile/public/update/avatar 返回的 `favoriteDjIds` 已改为直接读 `user_entity_follows`。
  - [x] `auth.controller.ts` profile update 提交 `favoriteDjIds` 时已改为只写 `user_entity_follows`。
  - [x] `djset.service.ts` contributor favorite DJs 展示已改为直接读 `user_entity_follows`。
  - [x] 用户端 / Admin 账号删除时已切为只清理 `user_entity_follows` / `user_genre_preferences`，不再清理旧 `follows` / `event_favorites`。
- [x] 关注数、粉丝数、收藏状态统一从 `user_entity_follows` 计算或同步。
- [x] 不再读写 `users.favorite_dj_ids`。
- [ ] 删除请求层对 legacy follow/favorite 兼容语义的隐式保留。

### 4.4 DJSet / Rating 切换

- [x] DJSet 详情改读 `dj_set_artists`。
- [x] DJSet 创建 / 编辑改写 `dj_set_artists`。
- [x] DJ 反查 set 改走 `dj_set_artists`。
- [x] DJSet 运行时不再回退读取 `co_dj_ids`。
- [x] DJSet 内容提交流程已同步写 `dj_set_artists`，不再依赖 `co_dj_ids`。
- [x] RatingUnit 详情改读 `rating_unit_dj_bindings`。
- [x] RatingUnit 创建 / 编辑改写 `rating_unit_dj_bindings`。
- [x] DJ 反查 rating unit 改走 `rating_unit_dj_bindings`。
- [x] RatingUnit 关联 DJ 展示已优先走 `rating_unit_dj_bindings`，不再用旧数组字段兜底。
- [x] DJ 详情 genre 本轮继续读 `djs.genres` 展示快照。
- [x] DJ 创建 / 编辑 genre 本轮继续写 `djs.genres` 展示快照。
- [ ] 请求层不再接受 `coDjIds` / 旧 DJSet 兼容字段。
- [ ] 返回层不再暴露 `coDjIds` 等 legacy 结构占位。

### 4.5 查询规范同步落地

改造后统一遵守下面几条：

1. 所有双向列表都走关系表
2. 所有列表都用 SQL 排序
3. 所有分页都用 SQL `limit / offset` 或 cursor
4. 数组/JSON 不参与正式关系查询
5. 关系表一律双向索引

### 可以接受的例外

- 聚合搜索结果的跨实体排序
- 推荐结果快照展示
- 纯展示态的前端重排

### 不可接受的例外

- 先全量查再 `.slice()`
- `has / hasSome` 替代正式关系表
- 主表维护一堆 `*_ids`

---

## Phase 5. 集成测试和发布前验收

- [x] 跑 Prisma generate。
- [x] 跑数据库 migration。
- [x] 跑迁移脚本。
- [x] 跑一致性校验脚本。
- [x] 跑后端单元测试 / 集成测试。
- [x] 跑 Event 详情接口回归。
- [x] 跑 DJ 详情接口回归。
- [x] 跑 Post / News feed 回归。
- [x] 跑 Follow / Favorite 回归。
- [x] 跑 DJSet / Rating 回归。
- [x] 跑后台编辑保存回归。
- [x] 检查慢查询，确认新查询走索引。
- [x] 确认所有旧数组查询 `has / hasSome` 已从核心路径移除。

Phase 5 验证命令（2026-05-20）：

- `pnpm exec tsc --noEmit`
- `pnpm run auth:integration`
- `pnpm run phase5:canonical:regression`
- `pnpm run phase5:query-plan-check`

---

## Phase 6. 上线切换和观察

仓库内准备项（2026-05-20）：

- 已新增生产切换手册：
  [canonical-relationships-production-cutover-runbook.md](/Users/blackie/Projects/raver/server/docs/canonical-relationships-production-cutover-runbook.md)
- 已新增只读 smoke 脚本：`pnpm run phase6:readonly:smoke`
- 已新增数据库切换脚本入口：`pnpm run phase6:cutover:db`

- [ ] 部署包含新 schema、新迁移脚本、新业务代码的版本。
- [ ] 执行生产备份。
- [ ] 确认生产写入口已冻结。
- [ ] 执行生产新表 migration。
- [ ] 执行生产全量迁移脚本。
- [ ] 执行生产一致性校验脚本。
- [ ] 校验通过后发布业务代码切换。
- [ ] 恢复必要写入口。
- [ ] 观察 Event 详情、DJ 详情、Post / News feed、Follow / Favorite、DJSet / Rating 核心链路。
- [ ] 观察错误日志、接口耗时、数据库慢查询、关键接口返回数量。
- [ ] 旧表保持只读，不立刻删除。

### 6.x 现阶段实际状态（2026-05-20）

- [x] 本地编译验证通过：
  - [x] `pnpm exec tsc --noEmit`
- [x] Phase 5 回归验证通过：
  - [x] `pnpm run auth:integration`
  - [x] `pnpm run phase5:canonical:regression`
  - [x] `pnpm run phase5:query-plan-check`
- [x] 真机手动验证已完成，当前判断可继续推进“去兼容”收口。
- [x] Follow / Favorite 主运行时链路已切为只读写 canonical 关系表：
  - [x] `/api/follows`
  - [x] `/v1/social/users/:id/follow`
  - [x] `/v1/djs/:id/follow`
  - [x] `/v1/events/:id/favorite`
- [x] DJSet 主运行时链路已切为只认 `dj_set_artists`：
  - [x] 创建
  - [x] 编辑
  - [x] 详情
  - [x] DJ 反查
- [x] Post / News 请求层 legacy key 兼容已在主链路删除。
- [ ] Event / Lineup 请求层 legacy 字段兼容尚未完全删除。
- [ ] Prisma schema 仍暴露旧字段 / 旧表，尚未进入 drop migration。
  - [x] Admin 用户列表/详情的 follow/follower 计数已切到 `user_entity_follows`，不再依赖旧 `User.follows / followers` relation 计数。
  - [x] Prisma schema 已移除 `User/Event/DJ` 上对旧 `follows` / `event_favorites` relation 的暴露。
  - [x] Prisma schema 已移除 `User.favorite_dj_ids` / `User.favorite_genres` 字段暴露。
  - [x] `rating_units.dj_ids` 的主运行时写入口已切除，Prisma schema 暴露也已移除。
  - [x] `dj_sets.co_dj_ids` 的主运行时读写已切除，Prisma schema 暴露也已移除。
  - [x] `posts.bound_*_ids` / `news_articles.bound_*_ids` 的主运行时读写已切除，Prisma schema 暴露也已移除。
  - [ ] 仍需继续清理 Prisma schema 对 `events.stage_order` / 旧 lineup&timetable 结构的暴露。

---

## Phase 7. 旧结构清理

### 7.1 进入清理的前提

- [ ] 新结构稳定运行至少一个观察周期。
- [ ] 没有业务代码读取旧数组字段。
- [ ] 没有业务代码写入旧数组字段。
- [ ] 没有定时任务依赖旧表。
- [ ] 旧结构回滚价值已经低于维护成本。

### 7.1A Runtime 去兼容收口

- [x] 删除 follow/favorite 主链路双写旧表。
- [x] 删除 DJSet 主链路对 `co_dj_ids` 的运行时回退。
- [x] 删除 RatingUnit 详情链路对旧 DJ 数组字段的运行时回退。
- [x] 删除 RatingUnit 创建 / 更新 / content submission 对旧 `rating_units.dj_ids` 写入的运行时依赖。
  - [x] `content-submission` 创建 rating 时已补齐 `rating_unit_dj_bindings` 同步。
- [x] 删除 Post / News 请求层对 legacy payload key 的兼容。
  - [x] `/v1/news` 创建链路已切为只认 `boundDjIds` / `boundBrandIds` / `boundEventIds`。
  - [x] `/v1/feed/posts` 创建/编辑链路已切为只认 `boundDjIds` / `boundBrandIds` / `boundEventIds`。
- [x] 删除 Event / Lineup / Timetable 请求层对 legacy 字段形状的兼容。
  - [x] `event.controller.ts` 的 Event create / update 主链路已停止写入旧 `lineup_artists` / `lineup_slots` 结构，改为只维护 canonical 表。
- [x] 删除 BFF / BFF Web / 通知中心 对 `eventID` 等 legacy 入参 / 响应别名的兼容。
  - [x] `feed` / `news bound` 查询入口已切为只认 `eventId`。
  - [x] `news bound` 查询入口已切为只认 `djId` / `festivalId` / `brandId`。
  - [x] `post` / `event live comment` 响应已改为返回 `eventId`。
  - [x] 新闻通知发布 metadata 已改为只写 `eventId` / `djId` / `brandId` / `newsId`。
  - [x] 通知中心 inbox 投影已改为只读 `eventId` / `djId` / `brandId` / `newsId`。
  - [x] 通知中心已读接口已切为只认 `itemId`。
  - [x] `bff.web.routes.ts` 的 Event 详情 / 列表主查询已移除对旧 lineup performer 补全兼容链。
  - [x] 继续清理其余 `eventID` / `brandID` / `djID` 等旧别名。
- [x] 删除 DJSet / content submission 请求层对 `coDjIds` / `eventID` / `djIDs` 等 legacy key 的兼容。
  - [x] content submission 的 News / ID 绑定字段已切为只认 `boundDjIds` / `boundBrandIds` / `boundEventIds`。
- [x] 删除 DJSet / content submission 对旧 `dj_sets.co_dj_ids` 写入的运行时依赖。
  - [x] DJSet create / update 已停止写入 `co_dj_ids` 空数组占位。
  - [x] `content-submission` 创建 DJSet 已停止写入 `co_dj_ids` 空数组占位。
- [x] 删除返回层对 legacy 结构占位字段的保留。
  - [x] DJSet 返回层已移除 `coDjIds` 占位字段。
  - [x] Post / News 返回层已改为返回 `boundDjIds` / `boundBrandIds` / `boundEventIds`，并移除 `legacyEventID` 占位。
  - [x] `event.controller.ts` 的 Event 详情 / 列表返回已改为基于 canonical 快照组装 `lineupArtists` / `lineupSlots` / `timetableSlots`。
  - [x] `bff.web.routes.ts` 的 `mapEvent` 已移除对旧 `lineupArtists` / `lineupSlots` / `timetableSlots` 的 fallback，活动主返回层改为 canonical-only。
  - [x] `bff.web.routes.ts` 的 `includeEventForWeb` 已移除旧 `lineupArtists` / `lineupSlots` / `timetableSlots` 查询，主活动详情改查 canonical 结构。
  - [x] 继续清理其余 legacy 占位 / 别名输出。
- [x] 再跑一轮全量搜索，确认 `server/src` 主运行时不再触达旧关系字段/旧关系表。
  - [x] Event 主链路（`event.controller.ts` / `bff.web.routes.ts` / `global-search.service.ts`）对旧 `lineup_slots` / `lineup_artists` 的直接 Prisma 读写已大幅切除，当前剩余命中主要为 API 输入名或 canonical 输出字段名。

### 7.1B 脚本与运维收口

- [x] 迁移脚本不再依赖旧结构作为数据来源。
  - [x] `migrate-canonical-relationships.ts` 已移除对 `Follow` / `EventFavorite` / `favorite_dj_ids` / `favorite_genres` 的 Prisma 字段访问，改为 raw SQL 读取旧表。
  - [x] `migrate-canonical-relationships.ts` 已移除对 `posts.bound_*_ids` / `news_articles.bound_*_ids` / `dj_sets.co_dj_ids` 的 Prisma 字段访问，改为 raw SQL 读取旧列。
  - [x] `migrate-canonical-relationships.ts` 已移除对 `rating_units.dj_ids` 的 Prisma 字段访问，改为 raw SQL 读取旧列。
  - [x] `migrate-canonical-relationships.ts` 已移除对 Event 旧 Prisma model（`event_lineup_artists` / `event_timetable_slots` / `event_lineup_slots`）的关键读取，改为 raw SQL 读取旧结构。
- [x] 校验脚本不再依赖旧结构做对照。
  - [x] `validate-canonical-relationships.ts` 已移除对 `Follow` / `EventFavorite` / `favorite_dj_ids` / `favorite_genres` 的 Prisma 字段访问，改为 raw SQL 读取旧表。
  - [x] `validate-canonical-relationships.ts` 主校验链路已移除对 `posts.bound_*_ids` / `news_articles.bound_*_ids` / `dj_sets.co_dj_ids` 的 Prisma 字段访问，改为 raw SQL 读取旧列。
  - [x] `validate-canonical-relationships.ts` 已移除对 `rating_units.dj_ids` 的 Prisma 字段访问，`sampleDjs` 中 DJSet / RatingUnit 旧数组对照也已切到 raw SQL。
  - [x] `validate-canonical-relationships.ts` 的 Event 旧结构对照（`event_lineup_artists` / `event_timetable_slots` / `event_lineup_slots` / `events.stage_order`）已切到 raw SQL。
- [x] smoke / regression 脚本更新为“只验证 canonical 结果”。
- [x] `src/scripts/benchmark-dj-event-query.ts` 已改为 canonical vs canonical 对比，不再查询旧 `event_lineup_artists`。
- [x] 管理后台 / 内容提交流程不再保留 legacy 兼容写法。
  - [x] 管理后台用户列表/详情 follow 计数已切到 canonical 关系表。
  - [x] `prisma/migrate-canonical-relationships.ts` 已退役为历史迁移保护入口，防止在 canonical-only schema 上误跑。
  - [x] `prisma/validate-canonical-relationships.ts` 已改为 canonical-only 健康检查，不再依赖旧表 / 旧列对照。

### 7.2 删除旧字段 / 旧表

#### 7.2A Phase 1 安全可删

- [x] 删除 `posts.bound_dj_ids`。
- [x] 删除 `posts.bound_brand_ids`。
- [x] 删除 `posts.bound_event_ids`。
- [x] 删除 `news_articles.bound_dj_ids`。
- [x] 删除 `news_articles.bound_brand_ids`。
- [x] 删除 `news_articles.bound_event_ids`。
- [x] 删除 `rating_units.dj_ids`。
- [x] 删除 `dj_sets.co_dj_ids`。
- [x] 删除 `users.favorite_dj_ids`。
- [x] 删除旧 `follows` 表。
- [x] 删除旧 `event_favorites` 表。
- [x] 已创建 Phase 1 drop migration 草案：`20260520173000_drop_legacy_relationship_columns_phase1`。

#### 7.2B Phase 2 仍有阻塞

- [x] 删除 `event_lineup_slots`。
- [x] 删除 `event_timetable_slots` 或把它彻底退出事实层。
- [x] 删除 `event_lineup_artists.dj_ids`，或完成 `event_lineup_artists` 到 `event_artists` 的最终重命名 / 替换。
- [x] 删除 `event_timetable_slots.dj_ids`。
- [x] 删除 `events.stage_order`。
- [x] `prisma/import-events-archive-bilingual.ts` 已改为直接同步 canonical Event lineup/timetable，不再写旧 `event_lineup_slots`。
- [x] `src/services/notification-center/notification-route-dj-reminder.scheduler.ts` 已改为直接读取 canonical `event_performances`。
- [x] `prisma/backfill-event-lineup-autobind-djs.ts` 已改为基于 canonical 快照回写 Event lineup/timetable，不再更新旧 `event_lineup_slots`。
- [x] 继续清理其余仍直接依赖旧 Event 结构的基准 / 修复脚本。
- [x] 已创建 Phase 2 drop migration 草案：`20260520193000_drop_legacy_event_structures_phase2`。

### 7.3 清理后验收

- [x] Prisma schema 不再暴露旧数组关系字段。
- [x] 代码中不再出现核心路径 `has / hasSome` 查询旧数组字段。
- [x] 代码中不再写 `event_lineup_slots`。
- [x] 代码中不再写 `follows` / `event_favorites`。
- [x] 数据库中 canonical 表是唯一正式关系事实来源。
- [x] 文档更新为新模型说明。

---

## 10. 优先级和核心路线

## P0：必须在本轮完成

- [x] Event / Lineup / Timetable 统一。
- [x] Post / News 绑定拆表。
- [x] Follow / Favorite 统一。
- [x] RatingUnit ↔ DJ 拆表。

## P1：建议本轮一起完成

- [x] DJSet ↔ DJ。
- [ ] DJ ↔ Genre 后续单独做，不进入本轮迁移。
- [ ] `brand` / `wikiFestival` 命名统一到 `festivalBrand` 语义。
- [x] 抽 `event-lineup-domain.service.ts`，去掉多处重复归一化逻辑。

## P2：可作为后续收尾

- [ ] SquadActivity.participants。
- [ ] UserVirtualAssetEquip.asset_ids。
- [ ] Label ↔ Genre。

---

## 11. 最后的最终建议

本次改造不要再拆成“先一点点兼容、后面再清”的路线。当前已经确认不会产生新数据，最适合直接执行：

**冻结写入 -> 建完整新表 -> 全量迁移 -> 全量校验 -> 一次性切换 -> 只读观察旧表 -> 删除旧结构。**

其中最核心的一刀仍然是：

**用 `event_artists + event_artist_members + event_stages + event_performances` 作为唯一正式 Lineup / Timetable 结构，退役 `event_lineup_slots`，不再让任何 `dj_ids` 数组承担关系事实。**

---

## 12. 推荐落地顺序总览

- [ ] 1. 冻结写入和定时任务。
- [ ] 2. 备份数据库并记录旧表基线。
- [x] 3. 建立全部 P0 / P1 canonical 新表。
- [x] 4. 编写并执行一次性全量迁移脚本。
- [x] 5. 编写并执行一致性校验脚本。
- [x] 6. 切换 Event / Lineup / Timetable 读写。
- [x] 7. 切换 DJ 详情活动反查。
- [x] 8. 切换 Post / News binding 读写。
- [x] 9. 切换 Follow / Favorite 读写。
- [x] 10. 切换 RatingUnit / DJSet 读写；Genre 本轮保持 `djs.genres` 展示快照。
- [ ] 11. 跑完整回归和慢查询检查。
- [ ] 12. 上线后观察核心链路。
- [x] 13. 稳定后删除旧字段和旧表。

### 12.1 当前执行看板（2026-05-20）

- [x] 已完成：Phase 5 四项验证全部通过。
- [x] 已完成：真机手动验证通过。
- [x] 已完成：Follow / Favorite runtime 双写已去掉。
- [x] 已完成：DJSet runtime fallback 已去掉。
- [x] 已完成：RatingUnit runtime fallback 已去掉。
- [x] 已完成：`RatingUnit.djIds` Prisma schema 暴露已移除，`prisma generate` / `tsc --noEmit` 已通过。
- [x] 已完成：DJSet / content submission 已停止写入 `dj_sets.co_dj_ids` 空数组占位。
- [x] 已完成：`DJSet.coDjIds` Prisma schema 暴露已移除，准备继续推进 `Post|News.bound_*_ids` schema 下线。
- [x] 已完成：`Post/News.bound_*_ids` Prisma schema 暴露已移除，主运行时绑定链路保持 canonical-only。
- [x] 已完成：`event.controller.ts` 的 Event create / update / get 主链路已切为 canonical-only，不再写旧 lineup 结构。
- [x] 已完成：`bff.web.routes.ts` 的 Event update rebase 判断 / publishes-me 统计已切到 canonical 快照，不再直接依赖旧 `lineup_slots` 读取。
- [x] 已完成：继续删除请求层 / 返回层 legacy 兼容字段，并推进 `bff.web.routes.ts` / 脚本层对 `Event / Lineup / Timetable` 旧结构的依赖下线。
- [x] 已完成：更新迁移脚本与校验脚本，脱离旧结构依赖。
- [x] 已完成：Prisma schema 清理与 drop migration。
- [x] 已完成：执行 Phase 2 migration 落库，并核验旧 Event 结构已从数据库移除。
- [x] 已完成：`canonical:validate` 已切为 canonical-only 健康检查并通过，`canonical:migrate` 已退役防误跑。
- [ ] 待做：生产切换 / 或直接以当前环境作为上线基线时的最终核对清单。

---

## 13. 当前代码证据附录

下面列的是本次核验里最关键的具体证据，方便后续逐项整改。

### 关系数组 / JSON 证据

- `users.favorite_dj_ids` / `users.favorite_genres`
  - `server/prisma/schema.prisma:29-30`
- `event_lineup_slots.dj_ids`
  - `server/prisma/schema.prisma:570-590`
- `event_lineup_artists.dj_ids`
  - `server/prisma/schema.prisma:593-609`
- `event_timetable_slots.dj_ids`
  - `server/prisma/schema.prisma:612-635`
- `djs.genres`
  - `server/prisma/schema.prisma:642-643`
- `genres.key_artists` / `genres.key_artist_bindings`
  - `server/prisma/schema.prisma:803-804`
- `dj_sets.co_dj_ids`
  - `server/prisma/schema.prisma:1168-1205`
- `rating_units.dj_ids`
  - `server/prisma/schema.prisma:1334-1355`
- `posts.bound_dj_ids / bound_brand_ids / bound_event_ids`
  - `server/prisma/schema.prisma:1381-1427`
- `news_articles.bound_dj_ids / bound_brand_ids / bound_event_ids`
  - `server/prisma/schema.prisma:1431-1458`
- `squad_activities.participants`
  - `server/prisma/schema.prisma:1834-1855`
- `user_virtual_asset_equips.asset_ids`
  - `server/prisma/schema.prisma:2518-2529`

### Lineup 结构重复演进证据

- 给旧 `event_lineup_slots` 追加 `dj_ids`
  - `server/prisma/migrations/20260405112000_add_event_lineup_slot_dj_ids/migration.sql`
- 新增 `event_lineup_artists` 与 `event_timetable_slots`，但没有淘汰旧表
  - `server/prisma/migrations/20260509193000_split_event_lineup_timetable/migration.sql`

### 当前查询仍依赖数组绑定的证据

- DJ 关注动态统计依赖 `posts.boundDjIds hasSome`
  - `server/src/services/notification-center/notification-followed-dj-update.scheduler.ts:87-110`
- DJ 关注动态统计依赖 `dj_sets.coDjIds hasSome`
  - `server/src/services/notification-center/notification-followed-dj-update.scheduler.ts:117-149`
- Brand 动态统计依赖 `posts.boundBrandIds hasSome`
  - `server/src/services/notification-center/notification-followed-brand-update.scheduler.ts:87-109`
- bound news feed 依赖 `boundEventIds / boundDjIds / boundBrandIds`
  - `server/src/routes/bff.routes.ts:6795-6822`
- DJ 反查 Event 依赖 `lineupSlots.some + djIds.has`
  - `server/src/routes/bff.web.routes.ts:8949-9003`
- DJ 反查 RatingUnit 依赖 `rating_units.djIds has`
  - `server/src/routes/bff.web.routes.ts:9037-9048`

### 当前 Lineup 读写重复与镜像存储证据

- BFF Web 中重复实现 lineup 归一化与 artist 推导
  - `server/src/routes/bff.web.routes.ts:900-1079`
- 同一事务里同时写 `event_timetable_slots` 和 `event_lineup_slots`
  - `server/src/routes/bff.web.routes.ts:1040-1079`
- Event controller 中存在另一套几乎同义的 lineup 归一化逻辑
  - `server/src/controllers/event.controller.ts:240-355`
- Event 映射时优先读 `timetableSlots`，否则退回 `lineupSlots`
  - `server/src/routes/bff.web.routes.ts:3832-3963`

### 内存排序 / 内存分页证据

- DJ 列表查完后再次在内存里按 followerCount 排序
  - `server/src/controllers/dj.controller.ts:293-300`
- Checkin overview 先全量取 `checkin`，再 `.slice(skip, skip + limit)`
  - `server/src/services/checkin-overview.ts:928-968`

这些证据已经足够支撑本方案中的结构结论与改造优先级。
