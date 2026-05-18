# Festival Viewer 地图能力二期改造计划（AMap + Apple MapKit JS + Mapbox + Geoapify）

更新时间：2026-04-16（Geoapify 已接入）
负责人：Codex（协作执行）
状态：进行中

---

## 1. 目标与范围

### 1.1 业务目标
1. 在 Web 管理端保留现有 AMap 能力，并新增 **MapKit JS + Mapbox + Geoapify** 的等价选点流程。
2. 管理者可在 Event 编辑/新建时主动选择地图提供方（AMap / MapKit / Mapbox / Geoapify）。
3. 四种地图最终落库为统一 `locationPoint` 结构，避免 App 端与地图供应商耦合。
4. iOS 端地图展示严格依赖已绑定的 `locationPoint`（已标点数据）。
5. 无地图定位数据时：
- Web 管理端不展示“地图定位查看入口”按钮。
- iOS 端不展示地图模块。

### 1.2 本次不做
1. Google Maps 接入（账号能力未就绪，后续单独阶段）。
2. 数据库结构大变更（沿用现有 `locationPoint` 标准结构）。

---

## 2. 统一数据契约（保持不变）

统一使用 `locationPoint`：

```json
{
  "provider": "amap | mapkit | mapbox | geoapify",
  "sourceMode": "manual_search | composed_search | my_location | pin_drag | map_poi_click",
  "providerPlaceId": "string",
  "location": { "lng": 121.4737, "lat": 31.2304 },
  "nameI18n": { "zh": "", "en": "" },
  "addressI18n": { "zh": "", "en": "" },
  "formattedAddressI18n": { "zh": "", "en": "" },
  "city": "",
  "district": "",
  "province": "",
  "countryCode": "",
  "providerMeta": {
    "amap": { "poiId": "", "adcode": "" },
    "mapkit": { "mapItemIdentifier": "" },
    "mapbox": { "placeId": "", "featureType": "" },
    "geoapify": { "placeId": "", "featureType": "" }
  }
}
```

---

## 3. Web 端功能对齐（MapKit / Mapbox / Geoapify 路径）

### 3.1 与 AMap 对齐的核心能力
1. 关键词搜索地点（手动搜索）。
2. 基于国家+城市+详细地址组合关键词搜索（组合搜索）。
3. 地图点击/地图移动后按中心点反查候选地点。
4. 使用“我的位置”定位并生成候选。
5. 候选地点列表：
- 第一项为“当前选定地址”（仅通过“设为候选地址”按钮变化）。
- 其余为候选地址，可点击卡片切换 POI 信息预览。
6. POI 信息面板与候选列表联动。
7. 确认绑定后写回统一 `locationPoint`。

### 3.2 多种标点方式（MapKit / Mapbox / Geoapify）
1. 搜索结果选点：关键词 -> 候选 -> 设为候选地址 -> 确认绑定。
2. 地图交互选点：单击地图（single-tap）生成临时点并反查。
3. 地图浏览选点：移动地图到目标区域，以中心点反查候选。
4. 我的位置选点：浏览器定位 -> 反查 -> 候选确认。

---

## 4. iOS 端展示规则

1. 地图模块展示前提：Event 已存在有效 `locationPoint.location(lat/lng)`。
2. 不再以“仅有文本地址”触发地图模块显示。
3. 地图页坐标、标题、查询文本都优先来自 `locationPoint`。

---

## 5. 实施阶段与进度看板

| 阶段 | 内容 | 状态 | 说明 |
|---|---|---|---|
| P1 | 新建本计划文档与清单 | Done | 当前文件 |
| P2 | Runtime Config 扩展（MapKit/Mapbox Token） | Done | 已完成 `.env.local` 与 `/api/viewer/runtime-config` mapkit/mapbox token 输出 |
| P3 | Web 地图基础设施（MapKit/Mapbox/Geoapify loader/services） | Done | 已新增 provider 层、MapKit/Mapbox/Geoapify loader 与 service 封装 |
| P4 | Event 地图弹窗 Provider 选择 + 多 Provider 路径 | Done | 已接入 provider bridge，打通 AMap/MapKit/Mapbox/Geoapify 选点主流程 |
| P5 | Web 无定位时隐藏地图查看入口 | Done | 已在 Event 列表 info 区按 `locationPoint` 控制入口显隐 |
| P6 | iOS 无定位时隐藏地图模块 + 使用 locationPoint | Done | 已改为仅 `locationPoint` 坐标触发地图模块，坐标/文案优先来自 locationPoint |
| P7 | 回归与结果总结 | In Progress | 已完成 JS/TS 语法检查，待 Web 端 Geoapify 手工联调结论 |

---

## 6. 计划改动文件清单

### 6.1 新增
1. `scrapRave/festival-viewer/docs/MAPKIT_JS_EVENT_LOCATION_IMPLEMENTATION_PLAN.md`
2. `scrapRave/festival-viewer/js/core/map/20-map-provider.js`
3. `scrapRave/festival-viewer/js/core/map/20-mapkit-loader.js`
4. `scrapRave/festival-viewer/js/core/map/30-mapkit-services.js`
5. `scrapRave/festival-viewer/js/core/map/40-mapbox-loader.js`
6. `scrapRave/festival-viewer/js/core/map/50-mapbox-services.js`
7. `scrapRave/festival-viewer/js/core/map/60-geoapify-loader.js`
8. `scrapRave/festival-viewer/js/core/map/70-geoapify-services.js`
9. `scrapRave/festival-viewer/js/features/event/location/15-location-picker-provider-bridge.js`

### 6.2 修改
1. `scrapRave/.env.local`
2. `scrapRave/web_tool/server.py`
3. `scrapRave/festival-viewer.html`
4. `scrapRave/festival-viewer/css/festival-viewer.css`
5. `scrapRave/festival-viewer/js/features/event/location/10-location-picker-modal.js`
6. `scrapRave/festival-viewer/js/features/event/location/20-location-bind-and-sync.js`
7. `scrapRave/festival-viewer/js/core/helpers/20-lineup-sync-and-payload.js`
8. `server/src/routes/bff.web.routes.ts`
9. `mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift`

---

## 7. 验收标准

1. Web 编辑/新建 Event 时可选择 AMap / MapKit / Mapbox / Geoapify 执行选点。
2. MapKit / Mapbox / Geoapify 路径支持：搜索、地图点击、地图移动中心反查、我的位置、候选确认绑定。
3. 保存后 `locationPoint.provider` 正确记录（`amap` / `mapkit` / `mapbox` / `geoapify`）。
4. Web 未绑定定位时，不出现“🗺 地图定位”查看入口。
5. iOS 端仅在存在有效 `locationPoint` 坐标时显示地图模块。
6. iOS 地图打开展示使用 event 的已绑定坐标与地点文本。

---

## 8. 风险与回滚

1. 风险：MapKit JS API 字段与 AMap 不同，部分 POI 详情字段可能缺失。
- 处理：统一降级到 `formattedAddressI18n` + 坐标展示，不阻塞绑定。
2. 风险：浏览器定位权限被拒。
- 处理：保留搜索/地图点击/中心点反查路径。
3. 回滚：保留 AMap 原有链路，Provider 选择回退到 `amap` 即可不中断业务。

---

## 9. 实时进度日志

- 2026-04-15 23:26：创建新计划文档，完成 P1。
- 2026-04-15 23:26：开始 P2，准备注入 MapKit token 到 runtime-config。
- 2026-04-15 23:34：完成 P2：注入 `MAPKIT_JS_TOKEN`，并在 `web_tool/server.py` 的 runtime-config 返回 `mapkit.jsToken`。
- 2026-04-15 23:43：完成 P3：新增 `20-map-provider.js`、`20-mapkit-loader.js`、`30-mapkit-services.js`。
- 2026-04-15 23:54：推进 P4：新增 `15-location-picker-provider-bridge.js`，实现 AMap/MapKit 选择与 MapKit 选点主流程（搜索/地图点击/地图移动中心反查/我的位置/候选确认）。
- 2026-04-15 23:58：完成 P5：Web 活动列表在无 `locationPoint` 时隐藏“地图定位”查看按钮。
- 2026-04-15 23:59：完成 P6：iOS `EventDetailView` 地图模块改为仅基于 `locationPoint` 显示；执行 `xcodebuild`，BUILD SUCCEEDED。
- 2026-04-16 09:35：接入 Mapbox Runtime Config（`MAPBOX_ACCESS_TOKEN` + `/api/viewer/runtime-config`）。
- 2026-04-16 09:46：新增 `40-mapbox-loader.js`、`50-mapbox-services.js`，补齐 Mapbox 搜索、逆地理、候选合并与定位能力。
- 2026-04-16 10:05：Provider 桥接新增 `mapbox` 分支，完成 Mapbox 地图点击 POI、移动反查、候选与 POI 面板联动。
- 2026-04-16 10:28：补齐后端 `locationPoint.provider=mapbox` 白名单与 `providerMeta.mapbox` 规范化，确保保存/回显一致。
- 2026-04-16 13:10：新增 Geoapify loader/services，完成 `geoapify` provider 选点主流程（搜索、逆地理、周边候选、我的位置、POI 面板联动）。
- 2026-04-16 13:18：补齐后端 `locationPoint.provider=geoapify` 白名单与 `providerMeta.geoapify` 规范化，确保保存/回显一致。
