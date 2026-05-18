# Country 英文全称（`enFull`）全链路改造计划

## 1. 目标与约束

### 目标
- 在现有 `countryI18n.en`（ISO 3166-1 alpha-3，大写三字母）与 `countryI18n.zh` 的基础上，新增并打通：
  - `countryI18n.enFull`：国际标准英文全称（例如 `CHN -> China`, `USA -> United States`）。
- 改造范围覆盖：
  - `festival-viewer` 前端（编辑/创建/保存/展示/Coze 调用）
  - `scrapRave/web_tool/server.py`（Coze 中转与提取）
  - `server` Node BFF（读写规范化、返回给 iOS 的数据）
  - iOS 模型与展示逻辑（优先展示 `enFull`，筛选仍使用 alpha-3）
  - 数据库存量数据补齐方案（脚本化 backfill）

### 兼容策略
- 不破坏旧字段：`countryI18n.en` 继续保留并用于机器可判定逻辑（筛选/统计/国内外判定）。
- 展示层英文优先顺序：
  1. `countryI18n.enFull`
  2. `countryI18n.en`
  3. `countryI18n.zh`

---

## 2. 涉及位置总览

### A. 前端（festival-viewer）
- `scrapRave/festival-viewer/js/core/helpers/00-festival-core-utils.js`
  - 增加国家 `enFull` 推导与标准化工具函数。
- `scrapRave/festival-viewer/js/core/helpers/20-lineup-sync-and-payload.js`
- `scrapRave/festival-viewer/js/core/helpers/30-backend-sync-persist.js`
- `scrapRave/festival-viewer/js/core/save-sync/00-collect-and-save.js`
- `scrapRave/festival-viewer/js/features/import/20-add-event-modal.js`
- `scrapRave/festival-viewer/js/features/import/translate/00-text-plan-and-merge.js`
- `scrapRave/festival-viewer/js/features/event/location/20-location-bind-and-sync.js`（国家字段回填时保留 `enFull`）

### B. Coze 中转层（Python）
- `scrapRave/web_tool/server.py`
  - `extract_translation_info` / `extract_event_info` 增加 `countryI18n.enFull` 提取
  - Coze 请求/响应规范化支持 `country_en_full` / `countryI18n.enFull`

### C. Node BFF（数据库读写口）
- `server/src/routes/bff.web.routes.ts`
  - 国家字段的 normalize/resolve 增加 `enFull` 保留与推导
  - Event / DJ / WikiFestival 的 countryI18n 写入与返回统一带 `enFull`

### D. iOS
- `mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureModels.swift`
  - `WebBiText` 增加 `enFull` 可选字段
  - 地址拼接及展示在英文场景优先使用 `enFull`
- `mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift`
  - 本地化映射时 country 展示优先 `enFull`
- `mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventsModuleView.swift`
  - 国内/国外筛选继续用 `countryI18n.en`（alpha-3，不改）

### E. 数据库与回填
- JSON 字段无需 schema 变更（`country_i18n` 已为 JSONB）。
- 新增 backfill 脚本，批量为历史 `Event/DJ/WikiFestival` 填充 `countryI18n.enFull`。

---

## 3. Coze 侧字段契约（将同步给你去改 Coze 提示词）

### 输入（festival）
```json
{
  "festival": {
    "name_i18n": { "en": "", "zh": "" },
    "city_i18n": { "en": "", "zh": "" },
    "detail_address_i18n": { "en": "", "zh": "" },
    "country_i18n": { "en": "CHN", "zh": "中国", "en_full": "China" }
  }
}
```

### 输出（translated）
```json
{
  "translated": {
    "nameI18n": { "en": "", "zh": "" },
    "cityI18n": { "en": "", "zh": "" },
    "detailAddressI18n": { "en": "", "zh": "" },
    "countryI18n": { "en": "CHN", "zh": "中国", "enFull": "China" }
  }
}
```

### 规则
- `countryI18n.en` 必须是 ISO alpha-3（大写三字母）
- `countryI18n.enFull` 必须是国家英文全称
- `countryI18n.zh` 必须是中文国名
- 若 `enFull` 缺失，中转层会按 `en` 自动补全

### 给 Coze 平台的改造要求（可直接复制）
1. 输入 JSON 的 `country_i18n` 增加 `en_full` 字段。
2. 输出 JSON 的 `countryI18n` 增加 `enFull` 字段。
3. 输出约束必须同时满足：
   - `countryI18n.en` = ISO 3166-1 alpha-3（如 `CHN`、`USA`、`GBR`）
   - `countryI18n.enFull` = 英文全称（如 `China`、`United States`、`United Kingdom`）
   - `countryI18n.zh` = 中文国名（如 `中国`、`美国`、`英国`）
4. 若模型无法确认 `enFull`，允许留空，由中转层自动补齐；但 `en` 与 `zh` 不能随意缺失。
5. 不允许把 `enFull` 写成 alpha-3 代码，不允许把 `en` 写成国家英文全称。

---

## 4. 执行阶段与进度

| 阶段 | 内容 | 状态 | 备注 |
| --- | --- | --- | --- |
| P0 | 文档建立与影响面确认 | Done | 影响面与契约已固化 |
| P1 | festival-viewer 国家 `enFull` 工具与保存链路 | Done | 前端保存/翻译调用已接通 |
| P2 | web_tool Coze 中转链路 `enFull` | Done | 请求/提取/返回已支持 |
| P3 | server BFF 国家字段规范化与返回 | Done | Event + DJ + WikiFestival 已接通 |
| P4 | iOS 模型与展示适配 `enFull` | Done | `WebBiText` 已加 `enFull` 并用于英文展示 |
| P5 | 数据回填脚本（历史数据） | Done | 新增 `server/prisma/backfill-country-en-full.ts` |
| P6 | 回归验证与结果总结 | In Progress | 编译通过，待业务回归清单执行 |

---

## 5. 进度日志

- 2026-04-16：创建本计划文档，完成影响面盘点与阶段拆分，进入 P1 开发。
- 2026-04-16：完成前端（festival-viewer）国家 `enFull` 读写与展示优先级接入。
- 2026-04-16：完成 Coze 中转层（`web_tool/server.py`）`country_i18n.en_full`/`countryI18n.enFull` 双向支持。
- 2026-04-16：完成 Node BFF（`bff.web.routes.ts`）国家字段规范化与返回打通，`pnpm build` 通过。
- 2026-04-16：完成 iOS `WebBiText` 增加 `enFull`，英文显示优先 `enFull`。
- 2026-04-16：新增历史数据回填脚本 `server/prisma/backfill-country-en-full.ts`（支持 dry-run 与 `--apply`）。
