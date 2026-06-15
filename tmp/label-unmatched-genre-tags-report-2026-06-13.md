# 厂牌流派标签未跳转问题汇总

日期：2026-06-13

## 结论

当前厂牌页的流派标签点击逻辑是：

- 前端优先展示 `label.genres`
- 如果 `label.genres` 为空，才回退到 `genresPreview`
- 只有标签名能在 genre tree 中查到对应 `genreId` 时，标签才会变成可点击链接
- 查不到时，标签仍会显示，但只是普通文字，不会跳转

本次全量检查结果：

- 厂牌总数：447
- `label.genres` 中存在“显示但不可跳转标签”的厂牌：150
- `genresPreview` 回退路径中的不可跳转标签：0
- 未匹配唯一标签数：14

这说明问题全部集中在结构化字段 `label.genres`，不是 `genresPreview`。

## 建议总表

| 标签 | 出现次数 | 建议动作 | 建议目标 | 说明 |
| --- | ---: | --- | --- | --- |
| Electronica | 66 | 新建 | 新建 `Electronica` | 高频、稳定、明确属于电子音乐语境，不建议删除。 |
| Big Room | 28 | 归并 | `Big Room House` | 现有树里已有标准节点，语义基本一致。 |
| Minimal | 21 | 归并 | `Minimal Techno` | 建议默认归到 `Minimal Techno`，与当前 DJ 侧 alias 方向保持一致。 |
| Dance | 20 | 删除 | - | 过于宽泛，不是稳定电子流派，不建议强行映射。 |
| Hip-Hop | 12 | 删除 | - | 非电子音乐主标签。 |
| Pop | 12 | 删除 | - | 过于宽泛，且很多厂牌并非电子流派语义。 |
| Drum & Bass | 11 | 归并 | `Drum and Bass` | 只是命名写法不同，应直接归并。 |
| Psy-Trance | 7 | 归并 | `Psytrance` | 只是命名写法不同，应直接归并。 |
| Breaks | 4 | 归并 | `Breakbeat` | 在电子音乐语境里通常可收敛到 `Breakbeat`。 |
| Rock | 3 | 删除 | - | 非电子音乐主标签。 |
| Indie Rock | 2 | 删除 | - | 非电子音乐主标签。 |
| Trap | 2 | 归并 | `Trap (EDM)` | 当前库里已有电子语境下的 `Trap (EDM)`。 |
| Metal | 1 | 删除 | - | 非电子音乐主标签。 |
| Punk | 1 | 删除 | - | 非电子音乐主标签。 |

## 详细说明

### 1. 建议新建

#### Electronica

- 次数：66
- 示例厂牌：`Hybrid Trap`、`Young Turks`、`NCS (NoCopyrightSounds)`、`CHAPTERD`、`Feel Hype`
- 建议：新建一个正式 genre 节点 `Electronica`
- 原因：
  - 这是高频标签，不是零星脏数据
  - 概念稳定，用户也能理解
  - 如果直接删除，会让大量电子厂牌失去本来合理的流派入口

### 2. 建议归并到现有 genre

#### Big Room -> Big Room House

- 次数：28
- 示例厂牌：`Spinnin' Records`、`Protocol Recordings`、`Quantum Beats`、`Maxximize`、`Musical Freedom`
- 建议：直接映射到现有节点 `Big Room House`

#### Minimal -> Minimal Techno

- 次数：21
- 示例厂牌：`Lethal Dose Recordings`、`Bosphorus Underground Recordings`、`Poker Flat Recordings`、`Minus`、`Techno Brothers`
- 建议：默认映射到现有节点 `Minimal Techno`
- 备注：
  - 这个标签有一点语义压缩，理论上也可能落在 `Minimal Tech House`
  - 但如果先追求全量可点击和统一口径，`Minimal Techno` 是当前更稳的默认目标

#### Drum & Bass -> Drum and Bass

- 次数：11
- 示例厂牌：`Hospital Records`、`Shogun Audio`、`Monstercat`
- 建议：直接映射到现有节点 `Drum and Bass`

#### Psy-Trance -> Psytrance

- 次数：7
- 示例厂牌：`Iboga Records`、`Iono Music`、`Dharma Music`
- 建议：直接映射到现有节点 `Psytrance`

#### Breaks -> Breakbeat

- 次数：4
- 示例厂牌：`Punks`、`Elektroshok Records`、`Otodayo Records`、`BomBeatz Music`
- 建议：直接映射到现有节点 `Breakbeat`

#### Trap -> Trap (EDM)

- 次数：2
- 示例厂牌：`Gravitas Recordings`、`Mafia Family`
- 建议：映射到现有节点 `Trap (EDM)`

### 3. 建议直接删除

以下标签建议从 `label.genres` 中直接删除，不保留展示，也不做跳转：

- `Dance`
- `Hip-Hop`
- `Pop`
- `Rock`
- `Indie Rock`
- `Metal`
- `Punk`

原因：

- 这些标签要么过于宽泛，要么是明显非电子音乐主标签
- 如果强行归到某个电子 genre，误导风险比“直接删除”更高
- 这和前面对 DJ 标签的处理原则是一致的

## 执行优先级建议

### 第一批：低风险立即处理

- `Big Room -> Big Room House`
- `Drum & Bass -> Drum and Bass`
- `Psy-Trance -> Psytrance`
- `Breaks -> Breakbeat`
- `Trap -> Trap (EDM)`

### 第二批：直接删除

- `Dance`
- `Hip-Hop`
- `Pop`
- `Rock`
- `Indie Rock`
- `Metal`
- `Punk`

### 第三批：需要补节点

- 新建 `Electronica`

### 第四批：可先统一，后续再细化

- `Minimal -> Minimal Techno`

## 备注

- 本次没有发现 `genresPreview` 路径里的新增未处理标签
- 所有问题都来自 `label.genres`
- 如果按这份建议处理，厂牌页里当前这批“显示但不可点击”的标签问题就可以基本清掉
