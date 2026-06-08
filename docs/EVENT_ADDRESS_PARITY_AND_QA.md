# Event Address Parity And QA

> Status: Active
> Owner: Backend / Web / iOS
> Last Updated: 2026-06-08
> Applies To: `server/`, `web/`, `mobile/ios/RaverMVP/`, `contracts/fixtures/event/golden/`

## 1. 目标

这份文档只服务于 event 地址主线的最终一致性验收。

当前终局模型：

- 顶层 `venueName` 已删除
- 顶层 `venueAddress` 已删除
- `manualLocation` 只承担活动地址真值
- `locationPoint` 只承担地图定位真值与场地展示真值
- `locationPoint.manualSetAddressI18n` 是有 `locationPoint` 时的场地展示第一真值

## 2. 字段职责

### 活动地址真值

- `manualLocation.detailAddressI18n`
  - 手填详细地址原文
- `manualLocation.formattedAddressI18n`
  - 对外统一展示的活动地址
  - 必须由 `detailAddress + city + country` 稳定生成

### 场地 / 地图展示真值

- `locationPoint.formattedAddressI18n`
  - provider 原始格式化地址
- `locationPoint.manualSetAddressI18n`
  - 用户最终确认的场地展示地址
- `locationPoint.nameI18n`
  - POI 名称元数据
  - 不再作为前台主展示地址

## 3. 展示规则

### 活动地址

只展示：

- `manualLocation.formattedAddressI18n`

### 场地字段 / map pin 文案

有 `locationPoint` 时：

1. `locationPoint.manualSetAddressI18n`
2. `locationPoint.formattedAddressI18n`

无 `locationPoint` 时：

1. `manualLocation.formattedAddressI18n`
2. `manualLocation.detailAddressI18n`

## 4. Golden Fixtures

当前 event 地址主线 golden fixture：

- `contracts/fixtures/event/golden/create-map-poi.json`
  - 覆盖 POI-backed create
  - 要点：
    - `manualLocation.formattedAddressI18n` 是活动地址真值
    - `locationPoint.formattedAddressI18n` 保留 provider 格式化地址
    - `locationPoint.manualSetAddressI18n` 保留最终场地展示地址
- `contracts/fixtures/event/golden/update-clear-location.json`
  - 覆盖地址清空
  - 要点：
    - `manualLocation = null`
    - `locationPoint = null`
    - `clearManualLocation = true`
    - `clearLocationPoint = true`
    - `clearLatitude = true`
    - `clearLongitude = true`

## 5. 自动化验证入口

### Server

- `pnpm --dir /Users/blackie/Projects/raver/server exec ts-node src/scripts/event-address-guardrails.ts`
- `pnpm --dir /Users/blackie/Projects/raver/server exec ts-node src/scripts/event-address-search-smoke.ts`
- `pnpm --dir /Users/blackie/Projects/raver/server exec ts-node src/scripts/phase6-event-address-smoke.ts`
- `pnpm --dir /Users/blackie/Projects/raver/server exec ts-node src/scripts/event-incremental-sync-regression.ts`

### Web

- `pnpm --dir /Users/blackie/Projects/raver/web test:parity:event`

### iOS

- `/Users/blackie/Projects/raver/scripts/run-ios-event-contract-parity.sh`

## 6. 手工测试 Checklist

- [ ] Web 新建 event，手填 `detailAddress + city + country`，提交后详情页“活动地址”正确显示 `manualLocation.formattedAddressI18n`
- [ ] Web 新建 event，地图选点后再提交，详情页“场地”显示 `locationPoint.manualSetAddressI18n`
- [ ] Web 编辑 event，只改 `detailAddress`，再次提交后：
  - [ ] `manualLocation.formattedAddressI18n` 变化
  - [ ] `locationPoint.manualSetAddressI18n` 同步变化
  - [ ] `locationPoint.formattedAddressI18n` 保持 provider 原值
- [ ] Web 清空地图点，提交后：
  - [ ] `locationPoint = null`
  - [ ] 场地展示回退到 `manualLocation`
- [ ] Web event 搜索分别用以下关键词可搜到目标 event：
  - [ ] `manualLocation.detailAddressI18n`
  - [ ] `manualLocation.formattedAddressI18n`
  - [ ] `locationPoint.manualSetAddressI18n`
  - [ ] `locationPoint.formattedAddressI18n`
  - [ ] `locationPoint.nameI18n`
- [ ] iOS event 详情页“活动地址”显示 `manualLocation.formattedAddressI18n`
- [ ] iOS event 详情页“场地”显示 `locationPoint.manualSetAddressI18n -> locationPoint.formattedAddressI18n`
- [ ] iOS map pin 文案与 open map query 语义一致
- [ ] share / widget / check-in / search 与 event detail 地址语义一致

## 7. 当前收口结论

截至 2026-06-08：

- web / iOS / server 已统一切换到最新地址模型
- `venueName` / `venueAddress` 不再属于 event 活跃写入与展示主线
- 地址搜索、详情、列表、catalog、share、widget、check-in 已按新语义验收
