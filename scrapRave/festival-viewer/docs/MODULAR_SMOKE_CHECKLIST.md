# Festival Viewer 模块化改造冒烟清单

更新时间：2026-04-15

## 自动化可验证项（已执行）

1. [Done] 全量 JS 语法检查（`node --check`）
2. [Done] `festival-viewer.html` 无内联大段 `<style>` / `<script>` 块
3. [Done] 模块脚本引用链存在且顺序可解析（`features/*` + `features/timetable/*`）
4. [Done] 函数名重复检测（跨 `js/` + `js/features/`）未发现重复定义
5. [Done] `core/* -> 00-app-core -> features/*` 依赖链顺序校验通过
6. [Done] `features/import/*` 子模块脚本链顺序校验通过
7. [Done] `features/dj/*` 子模块脚本链顺序校验通过
8. [Done] `features/brand/*` 子模块脚本链顺序校验通过
9. [Done] `features/news/*` 子模块脚本链顺序校验通过
10. [Done] `features/timetable/*` Import/Prefetch 子模块脚本链顺序校验通过
11. [Done] `features/ranking/*` 子模块脚本链顺序校验通过
12. [Done] `features/dj/profile/*` 子模块脚本链顺序校验通过
13. [Done] `core/archive/*` 子模块脚本链顺序校验通过
14. [Done] `features/import/runtime/*` 子模块脚本链顺序校验通过
15. [Done] `core/source-cache/*` 子模块脚本链顺序校验通过
16. [Done] `features/news/editor/*` 子模块脚本链顺序校验通过
17. [Done] `core/helpers/*` 子模块脚本链顺序校验通过
18. [Done] `core/save-sync/*` 子模块脚本链顺序校验通过
19. [Done] `core/bootstrap/*` 子模块脚本链顺序校验通过
20. [Done] `core/persistence/*` 子模块脚本链顺序校验通过
21. [Done] `features/timetable/bind/*` 子模块脚本链顺序校验通过
22. [Done] `features/dj/library/*` 子模块脚本链顺序校验通过
23. [Done] `features/import/translate/*` 子模块脚本链顺序校验通过
24. [Done] `ui/archive/*` 子模块脚本链顺序校验通过
25. [Done] `features/event/*` 子模块脚本链顺序校验通过
26. [Done] `features/brand/admin/*` 子模块脚本链顺序校验通过
27. [Done] `features/dj/profile/editor/*` 子模块脚本链顺序校验通过
28. [Done] `features/brand/binding/*` 子模块脚本链顺序校验通过
29. [Done] `features/timetable/import-compare/*` 子模块脚本链顺序校验通过
30. [Done] `features/ranking/entries/*` 子模块脚本链顺序校验通过
31. [Done] `core/state/*` 状态门面脚本链顺序校验通过
32. [Done] `ranking/00-board-editor.js` + `timetable/20-modal-and-render.js` facade 状态接入校验通过
33. [Done] `import/runtime/*` + `import/translate/*` + `import/20-add-event-modal.js` facade 状态接入校验通过
34. [Done] `core/bootstrap/05-event-bus.js` + `20-domcontentloaded-bindings.js` + `25-keyboard-dispatch.js` + `30-keyboard-shortcuts.js` 事件总线接入校验通过
35. [Done] `node --test tests/helpers-core-utils.test.js tests/helpers-core-utils-esm.test.mjs tests/keyboard-dispatch-esm.test.mjs tests/keyboard-actions-esm.test.mjs tests/helpers-lineup-sync-payload.test.js tests/helpers-lineup-sync-payload-esm.test.mjs tests/helpers-import-translate-text-plan-esm.test.mjs tests/helpers-import-runtime-transform-esm.test.mjs` 自动测试通过
36. [Done] `js/esm/core/helpers/festival-core-utils.mjs` import/export 试点与 `helpers-core-utils-esm.test.mjs` 校验通过
37. [Done] `js/esm/core/bootstrap/keyboard-dispatch.mjs` 启动链路 ESM 试点与 `keyboard-dispatch-esm.test.mjs` 校验通过
38. [Done] `js/core/helpers/20-lineup-sync-and-payload.js` payload/date 链路测试（`helpers-lineup-sync-payload.test.js`）通过
39. [Done] `js/esm/core/helpers/lineup-sync-payload-utils.mjs` ESM 试点与 `helpers-lineup-sync-payload-esm.test.mjs` 校验通过
40. [Done] `js/esm/features/import/translate/text-plan-utils.mjs` ESM 试点与 `helpers-import-translate-text-plan-esm.test.mjs` 校验通过
41. [Done] `js/esm/core/bootstrap/keyboard-actions.mjs` ESM 试点与 `keyboard-actions-esm.test.mjs` 校验通过
42. [Done] `js/esm/features/import/runtime/transform-mapper-utils.mjs` ESM 试点与 `helpers-import-runtime-transform-esm.test.mjs` 校验通过

## 手工交互冒烟项（待本地浏览器逐项确认）

1. [Pending] Archive 列表加载、年份/月筛选、全局搜索
2. [Pending] Event 编辑弹窗开关（点击编辑、Overlay 点击、ESC 关闭）
3. [Pending] Event 图片分区上传、已有图片改类型/删除、保存后回显
4. [Pending] Event / DJ 图片 lightbox 放大与下载
5. [Pending] DJ 列表加载、搜索/字母筛选、Profile 打开与保存
6. [Pending] DJ 导入链路（Spotify / Discogs / SoundCloud）与头像处理
7. [Pending] Timetable 打开、编辑、自动匹配、绑定 DJ、保存回写
8. [Pending] Brand / Event-Brand 绑定页 CRUD 与筛选
9. [Pending] News / Ranking 管理页关键操作（查询、编辑、保存）

## 本轮结构状态

- Core Archive 已拆分为：
  - `js/core/archive/00-asset-mapping.js`
  - `js/core/archive/10-cache-storage-and-meta.js`
  - `js/core/archive/20-hydrate-and-load.js`
- `js/core/10-archive-sync-cache.js` 仅保留兼容壳（2 行）
- Core Source Cache 已拆分为：
  - `js/core/source-cache/00-base-and-idb.js`
  - `js/core/source-cache/10-query-cache-and-logs.js`
  - `js/core/source-cache/20-avatar-and-display.js`
- `js/core/20-source-cache-common.js` 仅保留兼容壳（2 行）
- Core State Facade 已新增：
  - `js/core/state/00-ranking-state-facade.js`
  - `js/core/state/10-timetable-state-facade.js`
  - `js/core/state/20-import-state-facade.js`
- Core Persistence 已拆分为：
  - `js/core/persistence/00-idb-handle-store.js`
  - `js/core/persistence/10-folder-selection-bootstrap.js`
  - `js/core/persistence/20-scan-and-loading.js`
- `js/10-fs-persistence.js` 仅保留兼容壳（2 行）
- Core Helpers 已拆分为：
  - `js/core/helpers/00-festival-core-utils.js`
  - `js/core/helpers/10-lineup-poster-review.js`
  - `js/core/helpers/20-lineup-sync-and-payload.js`
  - `js/core/helpers/30-backend-sync-persist.js`
  - `js/core/helpers/40-coze-lineup-review.js`
- `js/20-helpers.js` 仅保留兼容壳（2 行）
- Core Save Sync 已拆分为：
  - `js/core/save-sync/00-collect-and-save.js`
  - `js/core/save-sync/10-header-and-view-render.js`
  - `js/core/save-sync/20-brand-binding-and-edit-fields.js`
  - `js/core/save-sync/30-editor-overlay-lifecycle.js`
- `js/30-save-sync.js` 仅保留兼容壳（2 行）
- Core Bootstrap 已拆分为：
  - `js/core/bootstrap/00-lightbox-core.js`
  - `js/core/bootstrap/05-event-bus.js`
  - `js/core/bootstrap/10-event-dj-image-preview.js`
  - `js/core/bootstrap/20-domcontentloaded-bindings.js`
  - `js/core/bootstrap/25-keyboard-dispatch.js`
  - `js/core/bootstrap/30-keyboard-shortcuts.js`
  - `js/core/bootstrap/40-float-nav-hooks.js`
- `js/core/bootstrap/20-domcontentloaded-bindings.js` + `25-keyboard-dispatch.js` + `30-keyboard-shortcuts.js` 已切换为“动作分发 + 事件总线/fallback”链路
- `js/70-lightbox-bootstrap.js` 仅保留兼容壳（2 行）
- UI Archive 已拆分为：
  - `js/ui/archive/00-filter-and-match.js`
  - `js/ui/archive/10-month-and-render.js`
  - `js/ui/archive/20-build-ui-and-tabs.js`
- `js/50-ui-render.js` 仅保留兼容壳（2 行）
- Event 已拆分为：
  - `js/features/event/00-image-zone-manager.js`
  - `js/features/event/10-archive-row-render.js`
- `js/features/event-image-zone-manager.js` 仅保留兼容壳（2 行）
- `js/features/archive-row-render.js` 仅保留兼容壳（2 行）
- Timetable 已拆分为：
  - `js/features/timetable/bind/00-match-map-and-identity.js`
  - `js/features/timetable/bind/10-musician-render.js`
  - `js/features/timetable/bind/20-bind-state-and-candidates.js`
  - `js/features/timetable/bind/30-bind-modal-actions-and-commit.js`
  - `js/features/timetable/10-import-bind-modal-core.js`
  - `js/features/timetable/import-compare/00-normalize-and-field-resolution.js`
  - `js/features/timetable/import-compare/10-grid-and-compare-render.js`
  - `js/features/timetable/import-compare/20-selection-actions-and-avatar.js`
  - `js/features/timetable/12-source-cache-prefetch.js`
  - `js/features/timetable/13-import-fetch-translate-save.js`
  - `js/features/timetable/20-modal-and-render.js`
- `js/features/timetable/20-modal-and-render.js` 已接入 `TimetableStateFacade.modalState()` 状态门面
- `js/features/timetable/00-bind-core.js` 仅保留兼容壳（2 行）
- `js/features/timetable/10-import-and-prefetch.js` 仅保留兼容壳（6 行）
- `js/features/timetable/11-import-source-compare.js` 仅保留兼容壳（2 行）
- `js/60-timetable.js` 仅保留状态初始化（14 行）
- DJ 已拆分为：
  - `js/features/dj/library/00-search-selection-state.js`
  - `js/features/dj/library/10-render-and-load.js`
  - `js/features/dj/library/20-bulk-translate-and-range.js`
  - `js/features/dj/10-auth.js`
  - `js/features/dj/profile/editor/00-basic-fields-and-avatar.js`
  - `js/features/dj/profile/editor/10-source-state-compare-fetch.js`
  - `js/features/dj/profile/editor/20-source-modal-lifecycle.js`
  - `js/features/dj/profile/10-render-and-list-sync.js`
  - `js/features/dj/profile/20-actions-and-modal.js`
- `js/features/dj/profile/00-edit-and-source.js` 仅保留兼容壳（2 行）
- `js/features/dj/00-library-and-bulk.js` 仅保留兼容壳（2 行）
- `js/features/dj/20-profile-editor.js` 仅保留兼容壳（2 行）
- `js/features/dj-management.js` 仅保留兼容壳（2 行）
- Brand 已拆分为：
  - `js/features/brand/admin/00-model-grid-loading.js`
  - `js/features/brand/admin/10-editor-form-lifecycle.js`
  - `js/features/brand/admin/20-media-save-delete.js`
  - `js/features/brand/binding/00-source-filter-candidates.js`
  - `js/features/brand/binding/10-table-render-selection.js`
  - `js/features/brand/binding/20-actions-batch-page.js`
- `js/features/brand/00-brand-admin.js` 仅保留兼容壳（2 行）
- `js/features/brand/10-event-brand-binding.js` 仅保留兼容壳（2 行）
- `js/features/brand-event-binding.js` 仅保留兼容壳（2 行）
- News 已拆分为：
  - `js/features/news/00-model-and-list.js`
  - `js/features/news/editor/00-draft-markdown-resources.js`
  - `js/features/news/editor/10-media-upload.js`
  - `js/features/news/editor/20-editor-overlay.js`
  - `js/features/news/20-binding-and-crud.js`
- `js/features/news-admin.js` 仅保留兼容壳（2 行）
- `js/features/news/10-editor-render-media.js` 仅保留兼容壳（2 行）
- Ranking 已拆分为：
  - `js/features/ranking/00-board-editor.js`
  - `js/features/ranking/10-entity-catalog-and-search.js`
  - `js/features/ranking/entries/00-normalize-render-and-summary.js`
  - `js/features/ranking/entries/10-catalog-actions-and-import.js`
  - `js/features/ranking/entries/20-lifecycle-payload-save.js`
- `js/features/ranking/00-board-editor.js` 已接入 `getRankingState()` 状态门面
- `js/features/ranking/20-entries-editor.js` 仅保留兼容壳（2 行）
- `js/features/ranking-admin.js` 仅保留兼容壳（2 行）
- Import Runtime 已拆分为：
  - `js/features/import/runtime/00-search-progress-live.js`
  - `js/features/import/runtime/10-transform-persist.js`
  - `js/features/import/runtime/20-festival-file-actions.js`
- `js/features/import/runtime/00-search-progress-live.js` + `10-transform-persist.js` 已接入 `ImportStateFacade.runtimeState()`
- Import Translate 已拆分为：
  - `js/features/import/translate/00-text-plan-and-merge.js`
  - `js/features/import/translate/10-modal-list-and-editor.js`
  - `js/features/import/translate/20-run-and-save.js`
- `js/features/import/translate/*` 与 `js/features/import/20-add-event-modal.js` 已接入 `ImportStateFacade.translateState()/addEventState()`
- 已新增测试基座：
  - `tests/helpers-core-utils.test.js`
  - `tests/helpers-core-utils-esm.test.mjs`
  - `tests/keyboard-dispatch-esm.test.mjs`
  - `tests/keyboard-actions-esm.test.mjs`
  - `tests/helpers-lineup-sync-payload.test.js`
  - `tests/helpers-lineup-sync-payload-esm.test.mjs`
  - `tests/helpers-import-translate-text-plan-esm.test.mjs`
  - `tests/helpers-import-runtime-transform-esm.test.mjs`
  - `tests/README.md`
- 已新增 ESM 试点模块：
  - `js/esm/core/helpers/festival-core-utils.mjs`
  - `js/esm/core/bootstrap/keyboard-dispatch.mjs`
  - `js/esm/core/bootstrap/keyboard-actions.mjs`
  - `js/esm/core/helpers/lineup-sync-payload-utils.mjs`
  - `js/esm/features/import/translate/text-plan-utils.mjs`
  - `js/esm/features/import/runtime/transform-mapper-utils.mjs`
- `js/features/import/00-translate-batch.js` 仅保留兼容壳（2 行）
- `js/features/import/10-import-runtime.js` 仅保留兼容壳（2 行）
