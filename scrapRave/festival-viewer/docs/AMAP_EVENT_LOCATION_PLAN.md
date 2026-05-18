# Festival Viewer Event 地图定位改造计划（高德地图 SDK）

更新时间：2026-04-15 15:32（Asia/Shanghai）

## 1. 目标与范围

### 1.1 目标

在 `festival-viewer` 的 Event 展示页与编辑页接入高德地图，支持：

1. 新增“定位地点信息”（除国家/城市/场所外）。
2. 两种导入方式：
   - 基于已有字段（国家+城市+场所）一键搜索候选并选择绑定。
   - 手动输入搜索关键词，独立选择绑定。
3. 地图中央 Pin 选点 + 可拖拽精调，并在 Pin 下方展示候选地点列表供确认。
4. 最终地点信息保存中英文版本（名称与地址）。
5. 地图查看能力：显示活动场所 Pin、支持“定位到我当前所在位置”。

### 1.2 范围边界

- 本期覆盖：Event 列表展示、Event 编辑弹窗、新增活动弹窗（Add Event）。
- 本期不覆盖：iOS 客户端原生地图接入、路线规划、批量反查历史数据自动补齐。

---

## 2. 当前系统现状（已确认）

当前 Event 数据链路主要在以下文件：

- 展示/编辑 UI：
  - `js/features/event/10-archive-row-render.js`
  - `js/core/save-sync/10-header-and-view-render.js`
- 表单采集与保存：
  - `js/core/save-sync/00-collect-and-save.js`
  - `js/core/helpers/20-lineup-sync-and-payload.js`
  - `js/core/helpers/30-backend-sync-persist.js`
- 后端数据映射回前端：
  - `js/core/archive/00-asset-mapping.js`
- 页面壳与样式：
  - `festival-viewer.html`
  - `css/festival-viewer.css`

---

## 3. 方案总览（架构）

## 3.1 新增数据模型（Event）

在 `fest.info` 与后端 Event payload 中新增 `locationPoint`（建议结构）：

```json
{
  "locationPoint": {
    "provider": "amap",
    "sourceMode": "composed_search | manual_search | pin_drag | my_location",
    "poiId": "B0XXXX",
    "location": { "lng": 121.4737, "lat": 31.2304 },
    "nameI18n": { "zh": "上海梅赛德斯-奔驰文化中心", "en": "Mercedes-Benz Arena" },
    "addressI18n": { "zh": "世博大道1200号", "en": "1200 Expo Ave" },
    "formattedAddressI18n": { "zh": "上海市浦东新区世博大道1200号", "en": "1200 Expo Ave, Pudong, Shanghai" },
    "adcode": "310115",
    "city": "Shanghai",
    "district": "Pudong",
    "province": "Shanghai",
    "selectedAt": "2026-04-15T10:25:00.000Z"
  }
}
```

## 3.2 模块拆分（建议新增）

- `js/core/map/00-amap-loader.js`
  - 统一加载 AMap JSAPI（幂等加载，避免重复注入）。
- `js/core/map/10-amap-services.js`
  - PlaceSearch / AutoComplete / Geocoder / Geolocation 封装。
- `js/features/event/location/00-location-state.js`
  - 当前事件选点草稿状态（候选列表、选中项、模式）。
- `js/features/event/location/10-location-picker-modal.js`
  - 地图选点弹窗（中心 Pin、搜索栏、候选列表、确认绑定）。
- `js/features/event/location/20-location-bind-and-sync.js`
  - 表单字段回填、payload 组装、展示回写。

## 3.3 UI 入口设计

- Event 编辑页：
  - 新增字段块“定位地点”。
  - 按钮：
    - `按国家/城市/场所搜索`
    - `手动搜索地点`
    - `打开地图选点`
    - `使用我的位置`
    - `清空定位`
- Event 展示页：
  - 新增只读显示：地点名称（中英）/ 地址（中英）/ 经纬度 / POI ID。
  - `查看地图`按钮（只读模式，显示活动 Pin + 我的定位按钮）。

---

## 4. 交互流程设计

## 4.1 方式 A：组合字段一键搜索

1. 读取 `country + location(city) + venueName/venueAddress` 组合 query。
2. 调用 PlaceSearch 获取候选。
3. 候选列表展示，点击任一候选：
   - 地图居中到该点。
   - Pin 同步到该点。
4. 用户确认后写入 `locationPoint`。

## 4.2 方式 B：手动搜索

1. 用户在地图搜索框输入关键词（AutoComplete + PlaceSearch）。
2. 结果点击后地图居中并更新 Pin。
3. 用户确认后写入 `locationPoint`。

## 4.3 Pin 精调（核心）

1. 地图中央固定 Pin（视觉中心）。
2. 用户拖地图或拖拽 Marker 后触发逆地理编码（Geocoder.getAddress）。
3. 以 Pin 所在点为中心做周边 POI 查询（PlaceSearch.searchNearBy）。
4. 在地图下方刷新候选列表，用户可再二次选择并确认。

## 4.4 当前定位

1. 点击“定位到我”调用 Geolocation.getCurrentPosition。
2. 成功后地图移动到用户位置并打点（不同样式 Marker）。
3. 用户可一键将“我所在位置”作为活动地点，或仅用于参考。

---

## 5. 中英文地址策略

目标：最终保存中英双语。

方案：

1. 中文主流程：用中文地图实例与服务拿到稳定 POI 结果。
2. 英文补齐：同坐标/同 POI 再做英文语言请求（AMap 多语言能力 + 服务层补齐）。
3. 若 SDK 直接英文字段缺失：
   - 回退为中文字段；
   - 同步标记 `i18nPending=true`（后续可做补全任务，不阻塞保存）。

---

## 6. 后端与接口改造点

## 6.1 Event API 扩展

- `POST /api/raver/events` / `.../update`：接收并存储 `locationPoint`。
- `GET /api/raver/events` / `.../:id`：返回 `locationPoint`。

## 6.2 可选代理（建议）

为安全与配额治理，建议增加服务端代理：

- `POST /api/raver/map/amap/search`
- `POST /api/raver/map/amap/geocode`
- `POST /api/raver/map/amap/regeo`

前端只调用本域 API，避免直接暴露敏感配置与跨域复杂度。

---

## 7. 文件级改造清单（执行顺序）

## 阶段 A：基础设施

1. `festival-viewer.html`
   - 新增地图弹窗容器（picker + viewer）。
   - 新增脚本引用（`js/core/map/*`, `js/features/event/location/*`）。
2. `css/festival-viewer.css`
   - 地图弹窗、中心 Pin、候选列表、按钮样式。
3. `js/core/map/*`
   - AMap 加载与服务封装。

## 阶段 B：Event 编辑页接入

1. `js/features/event/10-archive-row-render.js`
   - 编辑面板加“定位地点”字段和操作按钮。
2. `js/core/save-sync/20-brand-binding-and-edit-fields.js`
   - 编辑弹窗打开时回填 locationPoint。
3. `js/core/save-sync/00-collect-and-save.js`
   - 采集并提交 `locationPoint`。

## 阶段 C：后端同步与前端映射

1. `js/core/helpers/20-lineup-sync-and-payload.js`
   - `buildBackendEventUpsertPayload` 合并 locationPoint。
2. `js/core/archive/00-asset-mapping.js`
   - `mapBackendEventToFestival` 读取并注入 `info.locationPoint`。
3. `js/core/helpers/30-backend-sync-persist.js`
   - 保存后 patch 回本地 fest。

## 阶段 D：展示页只读地图与信息

1. `js/core/save-sync/10-header-and-view-render.js`
   - 详情区新增 locationPoint 展示（中英+坐标+POI）。
2. `js/features/event/location/10-location-picker-modal.js`
   - 增加只读查看模式（活动 Pin + 我的位置按钮）。

## 阶段 E：新增活动页接入（Add Event）

1. `js/features/import/20-add-event-modal.js`
   - 复用地图选点能力，创建时带上 `locationPoint`。

## 阶段 F：测试与验收

1. `tests/` 新增 map 相关纯函数测试（payload merge / i18n fallback）。
2. 人工冒烟：选择、拖针、保存、刷新回显、我的定位、移动端检查。

---

## 8. 验收标准（DoD）

1. Event 编辑页可通过两种方式检索并绑定地点。
2. 支持地图中心 Pin 精调，候选列表联动正常。
3. 保存后刷新页面不丢失，展示页可查看中英地点信息。
4. 地图可显示活动场所 Pin，并可定位到当前用户位置。
5. 无鉴权泄露风险，key/security 配置符合高德规范。
6. 不影响既有 Event 编辑、图片管理、lightbox、timetable 功能。

---

## 9. 风险与应对

1. 多语言地址完整性风险
   - 应对：中文主流程 + 英文补齐回退策略 + `i18nPending` 标记。
2. 浏览器定位失败（权限/HTTPS）
   - 应对：明确失败提示 + 手动搜索兜底。
3. SDK key 安全风险
   - 应对：使用安全密钥配置 + 服务端代理模式优先。
4. 现有单体页面回归风险
   - 应对：分阶段落地，每阶段可独立回归。

---

## 10. 官方文档依据（已核对）

- JS API 加载（Loader / AMapLoader）  
  https://lbs.amap.com/api/javascript-api-v2/guide/abc/load
- JS API 安全密钥（`window._AMapSecurityConfig`）  
  https://lbs.amap.com/api/javascript-api-v2/guide/abc/jscode
- 输入提示与 POI 搜索（AutoComplete / PlaceSearch）  
  https://lbs.amap.com/api/javascript-api-v2/guide/services/autocomplete
- 地理编码与逆地理编码（Geocoder）  
  https://lbs.amap.com/api/javascript-api-v2/guide/services/geocoder
- 定位插件（Geolocation / getCurrentPosition）  
  https://lbs.amap.com/api/javascript-api-v2/guide/services/geolocation
- 多语言地图（`languageCode`）  
  https://lbs.amap.com/api/javascript-api-v2/guide/map/englishmap

---

## 11. 实时进度看板（本文件持续更新）

状态说明：`Not Started` / `In Progress` / `Done` / `Blocked`

| ID | 任务 | 状态 | 更新时间 | 备注 |
|---|---|---|---|---|
| P0 | 输出本改造计划文档 | Done | 2026-04-15 09:25 | 本文件已创建 |
| P1 | 地图 SDK 基础设施（loader + services + modal shell） | Done | 2026-04-15 10:08 | 已完成 runtime-config、SDK loader、服务封装、地图弹窗骨架 |
| P2 | Event 编辑页接入地图选点（两种搜索 + Pin 精调） | Done | 2026-04-15 10:08 | 已支持组合搜索/手动搜索/拖拽 Pin/我的位置/确认绑定 |
| P3 | locationPoint 保存链路接入（collect/payload/sync） | Done | 2026-04-15 10:08 | 已接入 collect、backend payload、archive 映射与回填 |
| P4 | Event 展示页接入定位地点只读展示 + 查看地图 | Done | 2026-04-15 10:08 | 已接入详情展示与只读地图查看入口 |
| P5 | 新增活动页（Add Event）接入 locationPoint | Done | 2026-04-15 10:08 | 已补定位字段区与地图绑定动作，创建时随 payload 提交 |
| P6 | 回归与验收（功能 + 兼容 + 冒烟） | In Progress | 2026-04-15 10:08 | 语法检查与 Node 单测已通过，待补充浏览器人工冒烟记录 |
| P7 | 查看模式交互优化（固定锚点 + 临时探针 + 回到活动场地） | Done | 2026-04-15 15:32 | 已实现固定活动场地 Marker、可拖动探索 Pin、POI 窗口固定锚点信息、常驻回到活动场地按钮 |

## 12. 更新日志

- 2026-04-15 09:25：创建文档，完成需求拆解、阶段计划、文件级改造清单与实时进度看板初始化。
- 2026-04-15 09:38：开始阶段 P1；已创建 `scrapRave/.env.local` 并在 `web_tool/server.py` 增加本地 env 加载与 `/api/viewer/runtime-config` 接口。
- 2026-04-15 10:08：补齐 P2-P5 关键链路；修复候选地点点击后选中被覆盖问题；确认绑定时增加英文地址补齐；Add Event 弹窗接入 locationPoint 编辑与提交。
- 2026-04-15 10:08：完成语法校验（JS/Python）并通过 `festival-viewer/tests` 全量 Node 单测（39/39）。
- 2026-04-15 15:32：完成查看模式交互优化：活动场地固定锚点 Marker、探索 Pin 仅作临时移动、POI 面板固定展示活动场地信息、常驻“回到活动场地”按钮；并禁用查看模式下会改变候选/面板的联动逻辑。

---

## 13. 三地图并行接入改造方案（AMap + Google Maps + Apple MapKit）

更新时间：2026-04-15 10:40（Asia/Shanghai）

### 13.1 新目标

在 `festival-viewer` 后台中同时支持 3 个地图提供方：

1. AMap（已接入能力保留）
2. Google Maps（新增）
3. Apple MapKit JS（新增）

管理者在编辑 Event/Add Event 地点时可自行选择任一地图；三方最终都写入统一 `locationPoint` 结构，确保后端与 iOS 端解耦。

### 13.2 解耦原则（你提出的核心诉求）

1. 采集端可选地图：
   - 后台可用 Google 选点并保存。
2. 展示端可独立地图：
   - iOS 可用 Apple MapKit 展示同一地点（基于统一经纬度与标准地址）。
3. 不强绑定 provider：
   - `locationPoint` 中保存坐标与标准化地址字段，provider 仅作“采集来源”元信息。

### 13.3 统一落库数据结构（保持一致）

保持现有 `locationPoint` 主体，扩展 provider 元信息：

```json
{
  "locationPoint": {
    "provider": "amap | google | mapkit",
    "sourceMode": "composed_search | manual_search | pin_drag | my_location",
    "providerPlaceId": "provider native place id",
    "location": { "lng": 121.4737, "lat": 31.2304 },
    "nameI18n": { "zh": "...", "en": "..." },
    "addressI18n": { "zh": "...", "en": "..." },
    "formattedAddressI18n": { "zh": "...", "en": "..." },
    "city": "...",
    "district": "...",
    "province": "...",
    "countryCode": "CHN",
    "i18nPending": false,
    "selectedAt": "2026-04-15T10:40:00.000Z",
    "providerMeta": {
      "amap": { "adcode": "310115", "poiId": "B0..." },
      "google": { "placeId": "ChIJ...", "types": ["..."] },
      "mapkit": { "mapItemIdentifier": "..." }
    }
  }
}
```

说明：

1. 统一主字段只保留跨平台可消费信息（坐标 + i18n 地址）。
2. 供应商差异放入 `providerMeta`，避免污染主结构。
3. iOS 展示优先使用 `location + formattedAddressI18n`，与采集 provider 无关。

### 13.4 前端架构拆分（新增）

在现有地图模块上增加 provider 抽象层：

1. `js/core/map/20-provider-interface.js`
   - 定义统一接口（搜索、逆地理、附近、定位、地图实例、marker/pin 绑定）。
2. `js/core/map/30-provider-registry.js`
   - provider 注册与选择（`amap/google/mapkit`）。
3. `js/core/map/providers/amap-provider.js`
4. `js/core/map/providers/google-provider.js`
5. `js/core/map/providers/mapkit-provider.js`
6. `js/features/event/location/30-provider-selection-ui.js`
   - 弹窗顶部 provider 选择器（单选）。

### 13.5 统一 Provider 接口（建议）

```ts
interface MapProviderAdapter {
  id: 'amap' | 'google' | 'mapkit';
  ensureLoaded(): Promise<void>;
  createMap(container: HTMLElement, opts): Promise<MapInstance>;
  setCenter(map, lng: number, lat: number, zoom?: number): void;
  getCenter(map): { lng: number; lat: number };
  createDraggablePin(map, lng: number, lat: number, onDragEnd): PinInstance;
  searchByKeyword(query: string, opts): Promise<LocationPoint[]>;
  searchNearby(point, opts): Promise<LocationPoint[]>;
  reverseGeocode(point, opts): Promise<LocationPoint | null>;
  locateMe(opts): Promise<LocationPoint>;
  destroy?(map): void;
}
```

### 13.6 交互与功能对齐（3 Provider 一致）

三地图都必须支持：

1. 组合字段一键搜索（国家+城市+场馆）
2. 手动关键词搜索
3. 中心 Pin / 拖拽精调
4. 逆地理 + 周边候选列表
5. 使用我的位置
6. 只读查看模式（地图 + 场所 pin）

### 13.7 UI 改造点

1. 在地点弹窗顶部新增 `地图源选择`：
   - `AMap` / `Google Maps` / `Apple MapKit`
2. 默认策略：
   - 默认 AMap（可在设置中改默认）。
3. 切换 provider 行为：
   - 保留当前已选点坐标；
   - 用新 provider 重绘地图与候选列表；
   - 不自动覆盖用户确认结果。

### 13.8 后端与配置改造

#### 13.8.1 `.env.local`（新增项）

```env
AMAP_JS_API_KEY=
AMAP_SECURITY_JS_CODE=

GOOGLE_MAPS_JS_API_KEY=

APPLE_MAPKIT_JS_TOKEN=
# 或者改为服务端动态签发：
# APPLE_MAPKIT_TEAM_ID=
# APPLE_MAPKIT_KEY_ID=
# APPLE_MAPKIT_PRIVATE_KEY_P8_PATH=
```

#### 13.8.2 `runtime-config` 扩展

`/api/viewer/runtime-config` 返回：

```json
{
  "amap": { "jsApiKey": "...", "securityJsCode": "..." },
  "google": { "jsApiKey": "..." },
  "mapkit": { "jsToken": "..." }
}
```

### 13.9 分阶段实施路径（新增阶段 M）

| ID | 阶段 | 目标 | 状态 |
|---|---|---|---|
| M0 | 方案入档 | 将三地图方案写入本 MD | Done |
| M1 | 配置与 runtime | 扩展 env + runtime-config | Not Started |
| M2 | Provider 抽象层 | 接口/注册/状态管理完成 | Not Started |
| M3 | Google Provider | 完成搜索、逆地理、候选、定位、pin 拖拽 | Not Started |
| M4 | MapKit Provider | 完成搜索、逆地理、候选、定位、pin 拖拽 | Not Started |
| M5 | UI 与保存链路 | 弹窗 provider 选择 + 统一 locationPoint 落库 | In Progress |
| M6 | 回归验收 | 三 provider 冒烟 + 兼容验证 | Not Started |

### 13.10 验收标准（新增）

1. 三 provider 均可独立完成选点并保存。
2. 保存后 `locationPoint` 结构一致且通过现有保存链路。
3. 同一条 event：
   - 可用 Google 采集；
   - iOS 端可用 Apple MapKit 正常展示坐标与地址。
4. provider 切换不丢草稿，不误覆盖已确认地点。

### 13.11 你需要提供的 Key / 授权信息（执行清单）

#### A. Google Maps（必需）

1. `GOOGLE_MAPS_JS_API_KEY`
2. Google Cloud 启用 API：
   - Maps JavaScript API
   - Places API
   - Geocoding API
3. Key 限制策略：
   - Application restrictions: HTTP referrer
   - 允许：`http://127.0.0.1:*/*`、`http://localhost:*/*`

#### B. Apple MapKit JS（必需）

二选一（建议先给静态 token，后续再改动态签发）：

1. 方式 1：直接给 `APPLE_MAPKIT_JS_TOKEN`（可用期内）
2. 方式 2：给签发参数（推荐生产）
   - `TEAM_ID`
   - `KEY_ID`
   - MapKit JS 私钥 `.p8`
   - 允许域名配置（本地开发域名 + 生产域名）

#### C. AMap（已具备）

1. `AMAP_JS_API_KEY`
2. `AMAP_SECURITY_JS_CODE`

---

### 13.12 已完成的数据结构改造（2026-04-15）

已完成“先改造数据表与统一落库结构”的第一步：

1. 后端 `events` 表新增 `location_point (JSONB)` 字段（Prisma + migration）。
2. `POST /api/raver/events`、`PATCH /api/raver/events/:id` 已接入 `locationPoint` 读写。
3. `GET /api/raver/events*` 返回已标准化的 `locationPoint`（兼容旧字段）。
4. `locationPoint` 结构已支持：
   - `provider` / `sourceMode` / `providerPlaceId`
   - `location` / `nameI18n` / `addressI18n` / `formattedAddressI18n`
   - `city` / `district` / `province` / `countryCode`
   - `providerMeta`（amap/google/mapkit）
5. 兼容策略：
   - 旧 `poiId` / `adcode` 仍保留为兼容别名；
   - 当仅有旧经纬度字段时，API 会生成 fallback `locationPoint` 返回。

---

## 14. 更新日志（多地图扩展）

- 2026-04-15 10:40：新增“三地图并行接入（AMap + Google + MapKit）”完整方案、统一落库模型、分阶段实施路径与 Key/授权清单。
- 2026-04-15 15:58：完成多地图统一 `locationPoint` 的后端落库改造第一步：新增 `events.location_point`，并接入 create/update/list/detail 的标准化读写与兼容回填；本地开发库已执行 migration deploy。
