# Festival Viewer 模块化改造进度

更新时间：2026-04-15

## 总览

- 阶段 0：Done
- 阶段 1：Done
- 阶段 2：Done
- 阶段 3：Done
- 阶段 4：Done

## 阶段 0（基线建立）

1. [Done] 建立目录脚手架
2. [Done] 输出改造路径文档

## 阶段 1（壳化与资源外置）

1. [Done] 抽离内联 CSS 至外部文件（`css/festival-viewer.css`）
2. [Done] 拆分内联 JS 为顺序加载文件（8 个基础脚本）
3. [Done] 改造 HTML 为 Shell 引用模式（移除内联大段 CSS/JS）
4. [Done] 语法与关键路径验证（`node --check` 通过）

## 阶段 2（按域收敛模块）

1. [Done] 建立 `js/features`、`js/core` 目录骨架
2. [Done] 抽离 DJ 管理域模块
3. [Done] 抽离 Archive 行渲染模块（Event 卡片/编辑 UI）
4. [Done] 抽离 Event 图片分区管理模块
5. [Done] 抽离内容管理域模块（News + Ranking 编辑链路）
6. [Done] 增加阶段性冒烟清单与回归记录（自动化可验证项已落地）
7. [Done] 抽离 Brand + Event-Brand 绑定域模块
8. [Done] 抽离 Timetable 域模块（Bind / Import / Modal&Render）
9. [Done] 收敛 `js/core` 公共能力（状态/API/工具）并减少隐式全局依赖
进度备注：已完成七批 core 拆分（state/api、archive cache、source cache、persistence、helpers、save-sync、bootstrap 二次拆分）
10. [Done] 抽离 Ranking 展示页模块（榜单展示与加载链路）
11. [Done] 抽离 Import 域模块（批量翻译 / 抓取入库 / 新增活动）
12. [Done] 二次拆分内容管理域（News 与 Ranking 编辑管理解耦）
13. [Done] 二次拆分 DJ 管理域（列表批处理 / 鉴权 / 资料编辑解耦）
14. [Done] 二次拆分 Brand 管理域（Brand 编辑 / Event-Brand 绑定解耦）
15. [Done] 二次拆分 News 管理域（列表模型 / 编辑器渲染 / 绑定与 CRUD 解耦）
16. [Done] 二次拆分 Timetable Import/Prefetch 域（绑定弹窗 / 对比 / 缓存预抓取 / 入库解耦）
17. [Done] 二次拆分 Ranking 管理域（榜单编辑 / 实体匹配检索 / 位次编辑解耦）
18. [Done] 二次拆分 DJ Profile 管理域（编辑与多源替换 / 详情渲染 / 动作生命周期解耦）
19. [Done] 二次拆分 Core Archive 同步域（映射 / 缓存存储 / 加载入口解耦）
20. [Done] 二次拆分 Import Runtime 域（搜索进度 / 映射入库 / 文件动作解耦）
21. [Done] 二次拆分 Core Source Cache 域（基础/查询缓存/头像展示解耦）
22. [Done] 二次拆分 News Editor 媒体域（草稿资源/上传/弹窗生命周期解耦）
23. [Done] 二次拆分 Core Helpers 域（通用工具/海报识别/同步链路/Coze 审核解耦）
24. [Done] 二次拆分 Save Sync 域（采集保存/渲染回写/Brand 联想/编辑生命周期解耦）
25. [Done] 二次拆分 Bootstrap 域（Lightbox/事件绑定/快捷键/浮动导航解耦）
26. [Done] 二次拆分 Persistence 域（句柄存储/目录初始化/扫描加载解耦）
27. [Done] 结构标准化拆分 Timetable Bind Core（匹配索引/实体渲染/候选绑定/提交链路解耦）
28. [Done] 结构标准化拆分 DJ Library & Bulk（列表筛选/选择状态/批量任务编排解耦）
29. [Done] 结构标准化拆分 Import Translate Batch（弹窗状态/队列/翻译编排/回写解耦）
30. [Done] 结构标准化拆分 UI Render Core（筛选面板/月份年份渲染/主列表拼装解耦）
31. [Done] 结构标准化收拢 Event 列表与图片编辑子域（Row 渲染/图片分区管理）
32. [Done] 结构标准化拆分 Brand Admin（列表检索/编辑器生命周期/媒体上传回写）
33. [Done] 结构标准化拆分 DJ Profile Edit Core（基础字段/多源对比/replace 弹窗状态）
34. [Done] 结构标准化拆分 Event-Brand Binding（筛选检索/表格渲染/批量绑定动作）
35. [Done] 结构标准化拆分 Timetable Import Source Compare（字段映射/对比渲染/候选交互）
36. [Done] 结构标准化拆分 Ranking Entries Editor（位次渲染/导入匹配/保存提交）

## 阶段 3（状态管理与事件总线收口）

1. [Done] 新增域级状态门面（Ranking + Timetable）
2. [Done] `ranking/entries/*` 首批接入 `RankingStateFacade`
3. [Done] `timetable/import-compare/*` 与 `timetable/13-import-fetch-translate-save.js` 首批接入 `TimetableStateFacade`
4. [Done] `ranking/00-board-editor.js` 与 `timetable/20-modal-and-render.js` 接入 facade 状态访问
5. [Done] 收敛 Import 主链直连写入（Runtime / Translate / Add-Event）
6. [Done] 事件总线化（启动期绑定、快捷键、弹窗生命周期首批）

## 阶段 4（ESM 化与测试化）

1. [Done] 补充首批最小自动测试集（core helpers 纯函数）
2. [Done] ESM 化试点（纯工具链路 import/export 验证）
3. [Done] 扩大 ESM 覆盖范围（页面启动链路）
4. [Done] 扩大 ESM 覆盖范围（导入/保存等高价值子链路）
5. [Done] 补充 payload/date 链路自动测试集（lineup sync 与 upsert 相关纯函数）
6. [Done] 补充 payload/date 链路 ESM 试点（纯函数 import/export + 回归测试）
7. [Done] 补充 import/translate text-plan 链路 ESM 试点（纯函数 import/export + 回归测试）
8. [Done] 补充 startup keyboard actions 链路 ESM 试点（动作执行层 + 回归测试）
9. [Done] 补充 import/runtime transform mapper 链路 ESM 试点（映射纯函数 + 回归测试）

## 当前文件体量（阶段 2 收尾基线 + 阶段 3/4 增量）

- `js/00-app-core.js`：`7574` → `195` 行
- `js/40-import.js`：`2279` → `63` 行
- `js/50-ui-render.js`：`830` → `2` 行（兼容壳）
- 新增：`js/ui/archive/00-filter-and-match.js`（261 行）
- 新增：`js/ui/archive/10-month-and-render.js`（99 行）
- 新增：`js/ui/archive/20-build-ui-and-tabs.js`（74 行）
- `js/60-timetable.js`：`3153` → `14` 行
- `js/20-helpers.js`：`2151` → `2` 行（兼容壳）
- `js/30-save-sync.js`：`551` → `2` 行（兼容壳）
- `js/70-lightbox-bootstrap.js`：`702` → `2` 行（兼容壳）
- `js/10-fs-persistence.js`：`294` → `2` 行（兼容壳）
- 新增：`js/core/00-state-and-api.js`（288 行）
- 新增：`js/core/state/00-ranking-state-facade.js`（37 行）
- 新增：`js/core/state/10-timetable-state-facade.js`（88 行）
- 新增：`js/core/state/20-import-state-facade.js`（163 行）
- `js/core/10-archive-sync-cache.js`：`680` → `2` 行（兼容壳）
- 新增：`js/core/archive/00-asset-mapping.js`（327 行）
- 新增：`js/core/archive/10-cache-storage-and-meta.js`（265 行）
- 新增：`js/core/archive/20-hydrate-and-load.js`（88 行）
- `js/core/20-source-cache-common.js`：`361` → `2` 行（兼容壳）
- 新增：`js/core/source-cache/00-base-and-idb.js`（93 行）
- 新增：`js/core/source-cache/10-query-cache-and-logs.js`（198 行）
- 新增：`js/core/source-cache/20-avatar-and-display.js`（70 行）
- 新增：`js/core/persistence/00-idb-handle-store.js`（100 行）
- 新增：`js/core/persistence/10-folder-selection-bootstrap.js`（104 行）
- 新增：`js/core/persistence/20-scan-and-loading.js`（89 行）
- 新增：`js/core/helpers/00-festival-core-utils.js`（438 行）
- 新增：`js/core/helpers/10-lineup-poster-review.js`（498 行）
- 新增：`js/core/helpers/20-lineup-sync-and-payload.js`（448 行）
- 新增：`js/core/helpers/30-backend-sync-persist.js`（386 行）
- 新增：`js/core/helpers/40-coze-lineup-review.js`（383 行）
- 新增：`js/core/save-sync/00-collect-and-save.js`（123 行）
- 新增：`js/core/save-sync/10-header-and-view-render.js`（231 行）
- 新增：`js/core/save-sync/20-brand-binding-and-edit-fields.js`（148 行）
- 新增：`js/core/save-sync/30-editor-overlay-lifecycle.js`（47 行）
- 新增：`js/core/bootstrap/00-lightbox-core.js`（252 行）
- 新增：`js/core/bootstrap/05-event-bus.js`（65 行）
- 新增：`js/core/bootstrap/10-event-dj-image-preview.js`（82 行）
- 新增：`js/core/bootstrap/20-domcontentloaded-bindings.js`（275 行）
- 新增：`js/core/bootstrap/25-keyboard-dispatch.js`（71 行）
- 新增：`js/core/bootstrap/30-keyboard-shortcuts.js`（71 行）
- 新增：`js/core/bootstrap/40-float-nav-hooks.js`（124 行）
- `js/features/dj-management.js`：`2216` → `2` 行（兼容壳）
- `js/features/dj/00-library-and-bulk.js`：`740` → `2` 行（兼容壳）
- 新增：`js/features/dj/library/00-search-selection-state.js`（168 行）
- 新增：`js/features/dj/library/10-render-and-load.js`（233 行）
- 新增：`js/features/dj/library/20-bulk-translate-and-range.js`（339 行）
- 新增：`js/features/dj/10-auth.js`（187 行）
- `js/features/dj/20-profile-editor.js`：`1289` → `2` 行（兼容壳）
- `js/features/dj/profile/00-edit-and-source.js`：`647` → `2` 行（兼容壳）
- 新增：`js/features/dj/profile/editor/00-basic-fields-and-avatar.js`（121 行）
- 新增：`js/features/dj/profile/editor/10-source-state-compare-fetch.js`（467 行）
- 新增：`js/features/dj/profile/editor/20-source-modal-lifecycle.js`（61 行）
- 新增：`js/features/dj/profile/10-render-and-list-sync.js`（314 行）
- 新增：`js/features/dj/profile/20-actions-and-modal.js`（328 行）
- `js/features/archive-row-render.js`：`396` → `2` 行（兼容壳）
- `js/features/event-image-zone-manager.js`：`419` → `2` 行（兼容壳）
- 新增：`js/features/event/00-image-zone-manager.js`（419 行）
- 新增：`js/features/event/10-archive-row-render.js`（396 行）
- `js/features/content-admin.js`：`2365` → `3` 行（兼容壳）
- `js/features/news-admin.js`：`1379` → `2` 行（兼容壳）
- 新增：`js/features/news/00-model-and-list.js`（453 行）
- `js/features/news/10-editor-render-media.js`：`575` → `2` 行（兼容壳）
- 新增：`js/features/news/editor/00-draft-markdown-resources.js`（291 行）
- 新增：`js/features/news/editor/10-media-upload.js`（99 行）
- 新增：`js/features/news/editor/20-editor-overlay.js`（185 行）
- 新增：`js/features/news/20-binding-and-crud.js`（353 行）
- `js/features/ranking-admin.js`：`985` → `2` 行（兼容壳）
- 新增：`js/features/ranking/00-board-editor.js`（304 行）
- 新增：`js/features/ranking/10-entity-catalog-and-search.js`（199 行）
- `js/features/ranking/20-entries-editor.js`：`485` → `2` 行（兼容壳）
- 新增：`js/features/ranking/entries/00-normalize-render-and-summary.js`（198 行）
- 新增：`js/features/ranking/entries/10-catalog-actions-and-import.js`（150 行）
- 新增：`js/features/ranking/entries/20-lifecycle-payload-save.js`（150 行）
- 新增：`js/features/ranking-dashboard.js`（279 行）
- `js/features/brand-event-binding.js`：`1197` → `2` 行（兼容壳）
- `js/features/brand/00-brand-admin.js`：`655` → `2` 行（兼容壳）
- 新增：`js/features/brand/admin/00-model-grid-loading.js`（248 行）
- 新增：`js/features/brand/admin/10-editor-form-lifecycle.js`（268 行）
- 新增：`js/features/brand/admin/20-media-save-delete.js`（141 行）
- `js/features/brand/10-event-brand-binding.js`：`542` → `2` 行（兼容壳）
- 新增：`js/features/brand/binding/00-source-filter-candidates.js`（152 行）
- 新增：`js/features/brand/binding/10-table-render-selection.js`（170 行）
- 新增：`js/features/brand/binding/20-actions-batch-page.js`（220 行）
- `js/features/import/00-translate-batch.js`：`722` → `2` 行（兼容壳）
- 新增：`js/features/import/translate/00-text-plan-and-merge.js`（243 行）
- 新增：`js/features/import/translate/10-modal-list-and-editor.js`（360 行）
- 新增：`js/features/import/translate/20-run-and-save.js`（157 行）
- `js/features/import/10-import-runtime.js`：`750` → `2` 行（兼容壳）
- 新增：`js/features/import/runtime/00-search-progress-live.js`（435 行）
- 新增：`js/features/import/runtime/10-transform-persist.js`（333 行）
- 新增：`js/features/import/runtime/20-festival-file-actions.js`（99 行）
- 新增：`js/features/import/20-add-event-modal.js`（353 行）
- `js/features/timetable/00-bind-core.js`：`754` → `2` 行（兼容壳）
- 新增：`js/features/timetable/bind/00-match-map-and-identity.js`（169 行）
- 新增：`js/features/timetable/bind/10-musician-render.js`（128 行）
- 新增：`js/features/timetable/bind/20-bind-state-and-candidates.js`（287 行）
- 新增：`js/features/timetable/bind/30-bind-modal-actions-and-commit.js`（170 行）
- `js/features/timetable/10-import-and-prefetch.js`：`1893` → `6` 行（兼容壳）
- 新增：`js/features/timetable/10-import-bind-modal-core.js`（379 行）
- `js/features/timetable/11-import-source-compare.js`：`588` → `2` 行（兼容壳）
- 新增：`js/features/timetable/import-compare/00-normalize-and-field-resolution.js`（283 行）
- 新增：`js/features/timetable/import-compare/10-grid-and-compare-render.js`（158 行）
- 新增：`js/features/timetable/import-compare/20-selection-actions-and-avatar.js`（162 行）
- 新增：`js/features/timetable/12-source-cache-prefetch.js`（454 行）
- 新增：`js/features/timetable/13-import-fetch-translate-save.js`（475 行）
- 新增：`js/features/timetable/20-modal-and-render.js`（522 行）
- 新增：`js/esm/core/helpers/festival-core-utils.mjs`（180 行）
- 新增：`js/esm/core/bootstrap/keyboard-dispatch.mjs`（75 行）
- 新增：`js/esm/core/bootstrap/keyboard-actions.mjs`（33 行）
- 新增：`js/esm/core/helpers/lineup-sync-payload-utils.mjs`（333 行）
- 新增：`js/esm/features/import/translate/text-plan-utils.mjs`（79 行）
- 新增：`js/esm/features/import/runtime/transform-mapper-utils.mjs`（167 行）
- 新增：`tests/helpers-core-utils.test.js`（140 行）
- 新增：`tests/helpers-core-utils-esm.test.mjs`（77 行）
- 新增：`tests/keyboard-dispatch-esm.test.mjs`（48 行）
- 新增：`tests/keyboard-actions-esm.test.mjs`（54 行）
- 新增：`tests/helpers-lineup-sync-payload.test.js`（180 行）
- 新增：`tests/helpers-lineup-sync-payload-esm.test.mjs`（84 行）
- 新增：`tests/helpers-import-translate-text-plan-esm.test.mjs`（75 行）
- 新增：`tests/helpers-import-runtime-transform-esm.test.mjs`（82 行）
- 新增：`tests/README.md`（27 行）

## 变更记录

- 2026-04-14：创建 `festival-viewer/docs`、`festival-viewer/css`、`festival-viewer/js` 目录。
- 2026-04-14：新增 `MODULAR_REFACTOR_PLAN.md` 与本进度文件。
- 2026-04-14：完成阶段 1（Shell 化 + 资源外置 + 语法校验）。
- 2026-04-14：阶段 2 首批完成：
  - 新增 `js/features/` 模块目录；
  - `00-app-core.js` 抽离 DJ 管理域到 `features/dj-management.js`；
  - `50-ui-render.js` 抽离 Archive 行渲染到 `features/archive-row-render.js`；
  - `40-import.js` 抽离 Event 图片分区管理到 `features/event-image-zone-manager.js`；
  - `festival-viewer.html` 更新脚本引用顺序接入新模块。
- 2026-04-14：阶段 2 第二批完成：
  - `00-app-core.js` 抽离 News + Ranking 编辑链路到 `features/content-admin.js`；
  - `festival-viewer.html` 追加 `features/content-admin.js` 引用并完成语法校验。
- 2026-04-14：阶段 2 第三批完成：
  - `00-app-core.js` 抽离 Brand + Event-Brand 绑定链路到 `features/brand-event-binding.js`；
  - `festival-viewer.html` 追加 `features/brand-event-binding.js` 引用并完成语法校验。
- 2026-04-14：阶段 2 第四批完成：
  - `60-timetable.js` 按职责拆分到 `features/timetable/*` 三个模块；
  - `festival-viewer.html` 接入 Timetable 子模块链路；
  - 新增 `MODULAR_SMOKE_CHECKLIST.md`，沉淀自动化校验与手工冒烟清单。
- 2026-04-14：阶段 2 第五批完成：
  - `00-app-core.js` 前半段抽离至 `js/core/*`（state/api、archive cache、source cache）；
  - `festival-viewer.html` 调整为先加载 `core/*` 再加载 `00-app-core.js` 与 feature 模块；
  - 全量 `node --check` 与函数重名检测通过。
- 2026-04-14：阶段 2 第六批完成：
  - `00-app-core.js` 的 ranking 展示与加载链路抽离到 `features/ranking-dashboard.js`；
  - `00-app-core.js` 收敛为应用壳层（页面切换/入口）；
  - `festival-viewer.html` 更新 ranking 模块脚本引用并完成语法校验。
- 2026-04-14：阶段 2 第七批完成：
  - `40-import.js` 按职责拆分到 `features/import/*` 三个模块；
  - `festival-viewer.html` 接入 import 子模块链路；
  - 全量 `node --check` 与函数重名检测通过。
- 2026-04-14：阶段 2 第八批完成：
  - `features/content-admin.js` 二次拆分为 `features/news-admin.js` + `features/ranking-admin.js`；
  - `features/content-admin.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 调整脚本链路接入新模块并完成语法校验；
  - 新增 `SPLIT_STRUCTURE_GUIDE.md`，逐文件说明拆分边界与职责。
- 2026-04-14：阶段 2 第九批完成：
  - `features/dj-management.js` 二次拆分为 `features/dj/00-library-and-bulk.js` + `features/dj/10-auth.js` + `features/dj/20-profile-editor.js`；
  - `features/dj-management.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `features/dj/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第十批完成：
  - `features/brand-event-binding.js` 二次拆分为 `features/brand/00-brand-admin.js` + `features/brand/10-event-brand-binding.js`；
  - `features/brand-event-binding.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `features/brand/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第十一批完成：
  - `features/news-admin.js` 二次拆分为 `features/news/00-model-and-list.js` + `features/news/10-editor-render-media.js` + `features/news/20-binding-and-crud.js`；
  - `features/news-admin.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `features/news/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第十二批完成：
  - `features/timetable/10-import-and-prefetch.js` 二次拆分为 `features/timetable/10-import-bind-modal-core.js` + `11-import-source-compare.js` + `12-source-cache-prefetch.js` + `13-import-fetch-translate-save.js`；
  - `features/timetable/10-import-and-prefetch.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入新的 Timetable Import/Prefetch 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第十三批完成：
  - `features/ranking-admin.js` 二次拆分为 `features/ranking/00-board-editor.js` + `10-entity-catalog-and-search.js` + `20-entries-editor.js`；
  - `features/ranking-admin.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `features/ranking/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第十四批完成：
  - `features/dj/20-profile-editor.js` 二次拆分为 `features/dj/profile/00-edit-and-source.js` + `10-render-and-list-sync.js` + `20-actions-and-modal.js`；
  - `features/dj/20-profile-editor.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `features/dj/profile/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第十五批完成：
  - `core/10-archive-sync-cache.js` 二次拆分为 `core/archive/00-asset-mapping.js` + `10-cache-storage-and-meta.js` + `20-hydrate-and-load.js`；
  - `core/10-archive-sync-cache.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `core/archive/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第十六批完成：
  - `features/import/10-import-runtime.js` 二次拆分为 `features/import/runtime/00-search-progress-live.js` + `10-transform-persist.js` + `20-festival-file-actions.js`；
  - `features/import/10-import-runtime.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `features/import/runtime/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第十七批完成：
  - `core/20-source-cache-common.js` 二次拆分为 `core/source-cache/00-base-and-idb.js` + `10-query-cache-and-logs.js` + `20-avatar-and-display.js`；
  - `core/20-source-cache-common.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `core/source-cache/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第十八批完成：
  - `features/news/10-editor-render-media.js` 二次拆分为 `features/news/editor/00-draft-markdown-resources.js` + `10-media-upload.js` + `20-editor-overlay.js`；
  - `features/news/10-editor-render-media.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `features/news/editor/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第十九批完成：
  - `20-helpers.js` 二次拆分为 `core/helpers/00-festival-core-utils.js` + `10-lineup-poster-review.js` + `20-lineup-sync-and-payload.js` + `30-backend-sync-persist.js` + `40-coze-lineup-review.js`；
  - `20-helpers.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `core/helpers/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第二十批完成：
  - `30-save-sync.js` 二次拆分为 `core/save-sync/00-collect-and-save.js` + `10-header-and-view-render.js` + `20-brand-binding-and-edit-fields.js` + `30-editor-overlay-lifecycle.js`；
  - `30-save-sync.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `core/save-sync/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第二十一批完成：
  - `70-lightbox-bootstrap.js` 二次拆分为 `core/bootstrap/00-lightbox-core.js` + `10-event-dj-image-preview.js` + `20-domcontentloaded-bindings.js` + `30-keyboard-shortcuts.js` + `40-float-nav-hooks.js`；
  - `70-lightbox-bootstrap.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `core/bootstrap/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第二十二批完成：
  - `10-fs-persistence.js` 二次拆分为 `core/persistence/00-idb-handle-store.js` + `10-folder-selection-bootstrap.js` + `20-scan-and-loading.js`；
  - `10-fs-persistence.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `core/persistence/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第二十三批完成：
  - `features/timetable/00-bind-core.js` 二次拆分为 `features/timetable/bind/00-match-map-and-identity.js` + `10-musician-render.js` + `20-bind-state-and-candidates.js` + `30-bind-modal-actions-and-commit.js`；
  - `features/timetable/00-bind-core.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `features/timetable/bind/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第二十四批完成：
  - `features/dj/00-library-and-bulk.js` 二次拆分为 `features/dj/library/00-search-selection-state.js` + `10-render-and-load.js` + `20-bulk-translate-and-range.js`；
  - `features/dj/00-library-and-bulk.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `features/dj/library/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第二十五批完成：
  - `features/import/00-translate-batch.js` 二次拆分为 `features/import/translate/00-text-plan-and-merge.js` + `10-modal-list-and-editor.js` + `20-run-and-save.js`；
  - `features/import/00-translate-batch.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `features/import/translate/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第二十六批完成：
  - `50-ui-render.js` 二次拆分为 `ui/archive/00-filter-and-match.js` + `10-month-and-render.js` + `20-build-ui-and-tabs.js`；
  - `50-ui-render.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `ui/archive/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第二十七批完成：
  - `features/archive-row-render.js` + `features/event-image-zone-manager.js` 收拢至 `features/event/00-image-zone-manager.js` + `10-archive-row-render.js`；
  - 原文件保留兼容壳，降低旧路径误删/误引用风险；
  - `festival-viewer.html` 接入 `features/event/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第二十八批完成：
  - `features/brand/00-brand-admin.js` 二次拆分为 `features/brand/admin/00-model-grid-loading.js` + `10-editor-form-lifecycle.js` + `20-media-save-delete.js`；
  - `features/brand/00-brand-admin.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `features/brand/admin/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第二十九批完成：
  - `features/dj/profile/00-edit-and-source.js` 二次拆分为 `features/dj/profile/editor/00-basic-fields-and-avatar.js` + `10-source-state-compare-fetch.js` + `20-source-modal-lifecycle.js`；
  - `features/dj/profile/00-edit-and-source.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `features/dj/profile/editor/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第三十批完成：
  - `features/brand/10-event-brand-binding.js` 二次拆分为 `features/brand/binding/00-source-filter-candidates.js` + `10-table-render-selection.js` + `20-actions-batch-page.js`；
  - `features/brand/10-event-brand-binding.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `features/brand/binding/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第三十一批完成：
  - `features/timetable/11-import-source-compare.js` 二次拆分为 `features/timetable/import-compare/00-normalize-and-field-resolution.js` + `10-grid-and-compare-render.js` + `20-selection-actions-and-avatar.js`；
  - `features/timetable/11-import-source-compare.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `features/timetable/import-compare/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 2 第三十二批完成：
  - `features/ranking/20-entries-editor.js` 二次拆分为 `features/ranking/entries/00-normalize-render-and-summary.js` + `10-catalog-actions-and-import.js` + `20-lifecycle-payload-save.js`；
  - `features/ranking/20-entries-editor.js` 保留兼容壳，降低重复定义风险；
  - `festival-viewer.html` 接入 `features/ranking/entries/*` 脚本链路并完成语法校验。
- 2026-04-14：阶段 3 第一批完成：
  - 新增 `core/state/00-ranking-state-facade.js` + `core/state/10-timetable-state-facade.js`，建立 Ranking/Timetable 域状态门面；
  - `features/ranking/entries/*` 切换为通过 `getRankingState()` 访问状态；
  - `features/timetable/import-compare/*` 与 `features/timetable/13-import-fetch-translate-save.js` 切换为通过 Timetable facade 访问 bind/import 状态；
  - `festival-viewer.html` 接入 `core/state/*` 脚本链路并完成语法校验。
- 2026-04-15：阶段 3 第二批完成：
  - `features/ranking/00-board-editor.js` 切换为通过 `getRankingState()` 访问 Ranking 域状态；
  - `core/state/10-timetable-state-facade.js` 增加 `modalState()`，统一承载 Timetable Modal 核心状态访问；
  - `features/timetable/20-modal-and-render.js` 切换为通过 `TimetableStateFacade.modalState()` 访问 `currentFest/currentRow/editMode/draft/saving` 等核心状态；
  - 全量 `node --check` 与函数重名检测通过。
- 2026-04-15：阶段 3 第三批完成：
  - 新增 `core/state/20-import-state-facade.js`，统一承载 Import Runtime / Translate / Add-Event 状态访问；
  - `features/import/runtime/00-search-progress-live.js` 与 `10-transform-persist.js` 切换为通过 Import facade 访问主链状态；
  - `features/import/translate/*` 与 `features/import/20-add-event-modal.js` 切换为通过 Import facade 访问状态；
  - `festival-viewer.html` 接入 `core/state/20-import-state-facade.js` 脚本顺序并完成全量 `node --check` 校验。
- 2026-04-15：阶段 3 第四批完成：
  - 新增 `core/bootstrap/05-event-bus.js`，建立全局轻量事件总线（`on/off/emit/once`）与事件常量；
  - `core/bootstrap/20-domcontentloaded-bindings.js` 接入事件总线并集中处理 `ui:request-close` 与 Lightbox 导航事件；
  - `core/bootstrap/30-keyboard-shortcuts.js` 改为“键盘发事件 + 启动层分发执行”的解耦模式；
  - `core/bootstrap/00-lightbox-core.js` 增加 lightbox opened/closed 事件发射；
  - `festival-viewer.html` 接入 `core/bootstrap/05-event-bus.js` 脚本顺序并完成全量 `node --check` 与函数重名检测。
- 2026-04-15：阶段 4 第一批完成：
  - 新增 `tests/helpers-core-utils.test.js` 与 `tests/README.md`，建立首批 Node 自动测试基座（`node --test`）；
  - 覆盖 `core/helpers/00-festival-core-utils.js` 的核心纯函数（folder/image/i18n/date/id/source meta/country 解析）；
  - 修复 `splitEventRange` 将日期内连字符误拆分的问题（改为仅识别 `~ / — / – / to / 至 / 到 / 空格-空格`）；
  - 执行 `node --test tests/*.test.js`、全量 `node --check` 与函数重名检测，均通过。
- 2026-04-15：阶段 4 第二批完成：
  - 新增 `js/esm/core/helpers/festival-core-utils.mjs`，完成纯工具链路 ESM import/export 试点；
  - 新增 `tests/helpers-core-utils-esm.test.mjs`，补充 ESM 模块自动测试；
  - `tests/README.md` 更新为双测试入口执行方式；
  - 执行 `node --test tests/helpers-core-utils.test.js tests/helpers-core-utils-esm.test.mjs` 与全量语法检查，均通过。
- 2026-04-15：阶段 4 第三批完成：
  - 新增 `js/core/bootstrap/25-keyboard-dispatch.js`，将快捷键动作决策从执行层抽离为独立分发模块；
  - `js/core/bootstrap/30-keyboard-shortcuts.js` 改为“读取状态 + 调用分发 + 事件总线/fallback 执行”模式；
  - 新增 `js/esm/core/bootstrap/keyboard-dispatch.mjs`，完成页面启动链路首批 ESM 试点；
  - 新增 `tests/keyboard-dispatch-esm.test.mjs`，覆盖 close priority、lightbox 导航与状态映射；
  - `tests/README.md` 更新为三测试入口执行方式；
  - 执行 `node --test tests/helpers-core-utils.test.js tests/helpers-core-utils-esm.test.mjs tests/keyboard-dispatch-esm.test.mjs` 与全量语法检查，均通过。
- 2026-04-15：阶段 4 第四批完成：
  - 新增 `tests/helpers-lineup-sync-payload.test.js`，覆盖 `core/helpers/20-lineup-sync-and-payload.js` 的日期解析、day rollover、slot 生成与图片资产归一化；
  - `tests/README.md` 更新为四测试入口执行方式；
  - 执行 `node --test tests/helpers-core-utils.test.js tests/helpers-core-utils-esm.test.mjs tests/keyboard-dispatch-esm.test.mjs tests/helpers-lineup-sync-payload.test.js` 与全量语法检查，均通过。
- 2026-04-15：阶段 4 第五批完成：
  - 新增 `js/esm/core/helpers/lineup-sync-payload-utils.mjs`，完成 payload/date 链路 ESM 试点；
  - 新增 `tests/helpers-lineup-sync-payload-esm.test.mjs`，补齐对应 ESM 自动测试；
  - `tests/README.md` 更新为五测试入口执行方式；
  - 执行 `node --test tests/helpers-core-utils.test.js tests/helpers-core-utils-esm.test.mjs tests/keyboard-dispatch-esm.test.mjs tests/helpers-lineup-sync-payload.test.js tests/helpers-lineup-sync-payload-esm.test.mjs` 与全量语法检查，均通过。
- 2026-04-15：阶段 4 第六批完成：
  - 新增 `js/esm/features/import/translate/text-plan-utils.mjs`，完成导入链路 `import/translate` 文本规划纯函数 ESM 试点；
  - 新增 `tests/helpers-import-translate-text-plan-esm.test.mjs`，补齐对应 ESM 自动测试；
  - `tests/README.md` 更新为六测试入口执行方式；
  - 执行 `node --test tests/helpers-core-utils.test.js tests/helpers-core-utils-esm.test.mjs tests/keyboard-dispatch-esm.test.mjs tests/helpers-lineup-sync-payload.test.js tests/helpers-lineup-sync-payload-esm.test.mjs tests/helpers-import-translate-text-plan-esm.test.mjs` 与全量语法检查，均通过。
- 2026-04-15：阶段 4 第七批完成：
  - 新增 `js/esm/core/bootstrap/keyboard-actions.mjs`，完成启动链路快捷键动作执行层 ESM 试点；
  - 新增 `tests/keyboard-actions-esm.test.mjs`，补齐 close/navigate 执行层 ESM 自动测试；
  - `tests/README.md` 更新为七测试入口执行方式；
  - 执行 `node --test tests/helpers-core-utils.test.js tests/helpers-core-utils-esm.test.mjs tests/keyboard-dispatch-esm.test.mjs tests/keyboard-actions-esm.test.mjs tests/helpers-lineup-sync-payload.test.js tests/helpers-lineup-sync-payload-esm.test.mjs tests/helpers-import-translate-text-plan-esm.test.mjs` 与全量语法检查，均通过。
- 2026-04-15：阶段 4 第八批完成：
  - 新增 `js/esm/features/import/runtime/transform-mapper-utils.mjs`，完成导入链路 `import/runtime` 映射纯函数 ESM 试点；
  - 新增 `tests/helpers-import-runtime-transform-esm.test.mjs`，补齐导入映射 ESM 自动测试；
  - `tests/README.md` 更新为八测试入口执行方式；
  - 执行 `node --test tests/helpers-core-utils.test.js tests/helpers-core-utils-esm.test.mjs tests/keyboard-dispatch-esm.test.mjs tests/keyboard-actions-esm.test.mjs tests/helpers-lineup-sync-payload.test.js tests/helpers-lineup-sync-payload-esm.test.mjs tests/helpers-import-translate-text-plan-esm.test.mjs tests/helpers-import-runtime-transform-esm.test.mjs` 与全量语法检查，均通过。
