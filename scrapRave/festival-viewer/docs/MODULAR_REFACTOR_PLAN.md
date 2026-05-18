# Festival Viewer 模块化改造路径文档

## 1. 背景与目标

当前 `festival-viewer.html` 是超大单体文件（HTML + CSS + JS 混合），导致：

- 维护成本高：功能耦合严重，定位问题困难。
- 扩展风险高：新增需求容易引发跨区域回归。
- 协作效率低：多人并行开发冲突概率高。
- 测试粒度粗：缺乏明确模块边界，难以分层验证。

本次改造目标：

1. 将单体文件拆分为可维护、可扩展的模块结构。
2. 保持现有功能可用（行为不回退）。
3. 建立后续可持续演进的分层架构与迁移规范。

---

## 2. 目标架构（分层）

### 2.1 目录规划

```text
scrapRave/
  festival-viewer.html                  # 页面壳（Shell）
  festival-viewer/
    css/
      festival-viewer.css               # 先抽离整份样式（后续再细分）
    js/
      esm/
        core/
          bootstrap/
            keyboard-dispatch.mjs      # 阶段 4 ESM 启动链路试点（快捷键动作分发）
            keyboard-actions.mjs       # 阶段 4 ESM 启动链路试点（快捷键动作执行层）
          helpers/
            festival-core-utils.mjs     # 阶段 4 ESM 试点（纯函数 import/export）
            lineup-sync-payload-utils.mjs # 阶段 4 ESM 试点（payload/date 纯函数链路）
        features/
          import/
            runtime/
              transform-mapper-utils.mjs # 阶段 4 ESM 试点（import/runtime 映射纯函数）
            translate/
              text-plan-utils.mjs       # 阶段 4 ESM 试点（import/translate 文本规划纯函数）
      core/
        00-state-and-api.js             # 全局状态、常量、基础 API
        state/
          00-ranking-state-facade.js    # Ranking 域状态访问门面
          10-timetable-state-facade.js  # Timetable 域状态访问门面
          20-import-state-facade.js     # Import 域状态访问门面
        10-archive-sync-cache.js        # 兼容壳（已弃用，保留占位）
        archive/
          00-asset-mapping.js           # Archive 映射、lineup 转换、后端 event 映射
          10-cache-storage-and-meta.js  # Event 图片缓存、meta 与对象 URL 管理
          20-hydrate-and-load.js        # 缓存 hydration 与后端活动加载入口
        20-source-cache-common.js       # 兼容壳（已弃用，保留占位）
        source-cache/
          00-base-and-idb.js            # Source cache 基础结构、IDB 与序列化
          10-query-cache-and-logs.js    # Source cache 查询缓存、头像缓存与日志
          20-avatar-and-display.js      # Source 缩略头像与展示回退逻辑
        persistence/
          00-idb-handle-store.js        # 目录句柄持久化与权限检查
          10-folder-selection-bootstrap.js # 目录选择、恢复与初始化入口
          20-scan-and-loading.js        # 本地目录扫描与 loading 文案
        helpers/
          00-festival-core-utils.js     # Festival 通用解析/规范化/格式化工具
          10-lineup-poster-review.js    # Lineup 去重与海报识别弹窗流程
          20-lineup-sync-and-payload.js # 日期对齐、lineup slot 与 upsert payload 组装
          30-backend-sync-persist.js    # Event 图片同步与后端落库流程
          40-coze-lineup-review.js      # Coze lineup 识别审核与保存流程
        save-sync/
          00-collect-and-save.js        # Event 表单采集、校验与保存编排
          10-header-and-view-render.js  # Event 卡片头部与详情视图渲染
          20-brand-binding-and-edit-fields.js # Event↔Brand 编辑联想与表单填充
          30-editor-overlay-lifecycle.js # Event 编辑器 Overlay 生命周期
        bootstrap/
          00-lightbox-core.js           # Lightbox 核心渲染与下载流程
          05-event-bus.js               # 全局轻量事件总线与事件常量
          10-event-dj-image-preview.js  # Event/DJ 图片点击预览入口
          20-domcontentloaded-bindings.js # DOMContentLoaded 事件绑定与启动流程
          25-keyboard-dispatch.js       # 键盘动作分发优先级与 overlay 状态解析
          30-keyboard-shortcuts.js      # 全局 ESC 与左右键快捷键
          40-float-nav-hooks.js         # 浮动导航与页面函数拦截重建
      00-app-core.js                    # 应用壳层（页面切换、头部计数、ranking 列表入口）
      10-fs-persistence.js              # 兼容壳（已弃用，保留占位）
      20-helpers.js                     # 兼容壳（已弃用，保留占位）
      30-save-sync.js                   # 兼容壳（已弃用，保留占位）
      40-import.js                      # 导入流程
      50-ui-render.js                   # 兼容壳（已弃用，保留占位）
      ui/
        archive/
          00-filter-and-match.js        # 国家/活动类型筛选、搜索匹配与面板交互
          10-month-and-render.js        # 年月分组、主列表渲染与空态控制
          20-build-ui-and-tabs.js       # Archive UI 入口编排与年份导航
      60-timetable.js                   # timetable 状态壳（逐步瘦身）
      70-lightbox-bootstrap.js          # 兼容壳（已弃用，保留占位）
      features/
        import/
          00-translate-batch.js         # 兼容壳（已弃用，保留占位）
          translate/
            00-text-plan-and-merge.js   # 文本规则、翻译请求编排、草稿 payload
            10-modal-list-and-editor.js # 批量翻译弹窗、筛选列表、草稿编辑交互
            20-run-and-save.js          # 批量翻译执行与确认保存链路
          10-import-runtime.js          # 兼容壳（已弃用，保留占位）
          runtime/
            00-search-progress-live.js  # 搜索、进度轮询、实时入库队列
            10-transform-persist.js     # 抓取结果映射、图片落盘、索引重建
            20-festival-file-actions.js # 活动删除与文件夹打开
          20-add-event-modal.js         # 新增活动弹窗流程
        dj/
          00-library-and-bulk.js        # 兼容壳（已弃用，保留占位）
          library/
            00-search-selection-state.js # 列表检索、选择模式与工具栏状态
            10-render-and-load.js       # 列表渲染与库加载刷新
            20-bulk-translate-and-range.js # 批量双语化任务与索引区间选择
          10-auth.js                    # Viewer 登录鉴权与会话恢复
          20-profile-editor.js          # 兼容壳（已弃用，保留占位）
          profile/
            00-edit-and-source.js       # 兼容壳（已弃用，保留占位）
            editor/
              00-basic-fields-and-avatar.js # DJ 基础字段编辑与头像替换草稿
              10-source-state-compare-fetch.js # 多源候选状态、对比表与抓取编排
              20-source-modal-lifecycle.js # source replace 弹窗生命周期与开关
            10-render-and-list-sync.js  # DJ 详情渲染与列表同步
            20-actions-and-modal.js     # DJ 保存/删除/双语化与详情弹窗生命周期
        brand/
          00-brand-admin.js             # 兼容壳（已弃用，保留占位）
          admin/
            00-model-grid-loading.js    # Brand 列表检索、卡片渲染与页面加载刷新
            10-editor-form-lifecycle.js # Brand 编辑器生命周期与表单草稿同步
            20-media-save-delete.js     # Brand 媒体上传、保存与删除动作链路
          10-event-brand-binding.js     # 兼容壳（已弃用，保留占位）
          binding/
            00-source-filter-candidates.js # Event/Brand 来源筛选与候选收集
            10-table-render-selection.js   # 绑定表格渲染与行级选择交互
            20-actions-batch-page.js       # 单条/批量绑定动作与分页链路
        news/
          00-model-and-list.js          # News 解析、筛选、分组与列表渲染
          10-editor-render-media.js     # 兼容壳（已弃用，保留占位）
          editor/
            00-draft-markdown-resources.js # News 草稿、Markdown 与资源库
            10-media-upload.js          # News 媒体上传与封面选择
            20-editor-overlay.js        # News 编辑器弹窗渲染与生命周期
          20-binding-and-crud.js        # News 绑定检索、保存删除、加载刷新
        archive-row-render.js           # 兼容壳（已弃用，保留占位）
        event-image-zone-manager.js     # 兼容壳（已弃用，保留占位）
        event/
          00-image-zone-manager.js      # Event 图片分区与草稿管理
          10-archive-row-render.js      # Archive 列表行渲染
        dj-management.js                # 兼容壳（已弃用，保留占位）
        brand-event-binding.js          # 兼容壳（已弃用，保留占位）
        news-admin.js                   # 兼容壳（已弃用，保留占位）
        ranking-admin.js                # 兼容壳（已弃用，保留占位）
        ranking-dashboard.js            # Ranking 展示页与榜单加载链路
        ranking/
          00-board-editor.js            # Ranking 榜单编辑（新建/更新/删除/封面）
          10-entity-catalog-and-search.js # Ranking 实体目录/匹配/检索
          20-entries-editor.js          # 兼容壳（已弃用，保留占位）
          entries/
            00-normalize-render-and-summary.js # 位次归一化、汇总与表格渲染
            10-catalog-actions-and-import.js   # 位次行操作、目录回写与文本导入
            20-lifecycle-payload-save.js       # 编辑器生命周期、payload 收集与保存提交
        timetable/
          00-bind-core.js               # 兼容壳（已弃用，保留占位）
          bind/
            00-match-map-and-identity.js # DJ 匹配索引与身份解析
            10-musician-render.js       # 表演实体渲染与快捷绑定入口
            20-bind-state-and-candidates.js # 绑定状态与候选自动匹配
            30-bind-modal-actions-and-commit.js # 绑定弹窗动作与快速提交
          10-import-and-prefetch.js     # 兼容壳（已弃用，保留占位）
          10-import-bind-modal-core.js  # Timetable 导入绑定弹窗核心流程
          11-import-source-compare.js   # 兼容壳（已弃用，保留占位）
          import-compare/
            00-normalize-and-field-resolution.js # 候选归一化与字段值解析
            10-grid-and-compare-render.js        # 来源网格与对比表渲染
            20-selection-actions-and-avatar.js   # 候选选择、批量应用与头像预览
          12-source-cache-prefetch.js   # Timetable 多源缓存与预抓取任务
          13-import-fetch-translate-save.js # Timetable 抓取/翻译/入库与头像上传
          20-modal-and-render.js        # Timetable 弹窗编辑与渲染
    docs/
      MODULAR_REFACTOR_PLAN.md          # 本文档
      MODULAR_REFACTOR_PROGRESS.md      # 进度追踪
    tests/
      helpers-core-utils.test.js        # core helpers 纯函数最小回归集
      helpers-core-utils-esm.test.mjs   # core helpers ESM 试点回归集
      keyboard-dispatch-esm.test.mjs    # 启动链路键盘分发 ESM 试点回归集
      helpers-lineup-sync-payload.test.js # payload/date 链路回归集（lineup sync/upsert 纯函数）
      helpers-lineup-sync-payload-esm.test.mjs # payload/date ESM 试点回归集
      helpers-import-translate-text-plan-esm.test.mjs # import/translate text-plan ESM 试点回归集
      keyboard-actions-esm.test.mjs    # startup keyboard actions ESM 试点回归集
      helpers-import-runtime-transform-esm.test.mjs # import/runtime transform ESM 试点回归集
      README.md                         # 测试执行说明
```

### 2.2 分层原则

- `Shell 层`：仅保留页面结构与资源引用，不承载业务逻辑。
- `Style 层`：先整体抽离，再按主题拆分（base/pages/modals/components/responsive）。
- `Script 层`：按职责分块，先保证稳定加载顺序，再逐步消除全局耦合。
- `Feature 层`：按业务域（Event、DJ、Brand、News、Ranking、Timetable）继续下钻。

### 2.3 约束

- 阶段 1 不改变原有 API/DOM 协议，保证低风险迁移。
- 通过“顺序脚本加载”保持兼容；后续阶段再迁移到 ESM。

---

## 3. 改造阶段与里程碑

## 阶段 0：基线建立（当前）

- 建立目录与文档。
- 明确功能清单与风险点。

验收：

- 文档齐备，可执行。

## 阶段 1：壳化与资源外置（本轮执行）

- 抽离 `<style>` 到 `css/festival-viewer.css`。
- 拆分内联 `<script>` 为多文件按顺序加载。
- 保持原有函数名与事件绑定方式不变。

验收：

- 页面可正常加载。
- 主要路径可用：Archive 列表、Event 编辑、DJ 管理、图片 lightbox。

## 阶段 2：按域收敛模块

- 新增 `features/` 与 `core/` 目录（逻辑层继续细分）。
- 将 Event/DJ/Timetable 等域函数迁移到各自模块文件。
- 引入统一模块导出入口（兼容 window）。

验收：

- 每个域有独立文件边界。
- 跨域依赖通过统一接口访问。

### 阶段 2.5：结构标准化收尾（按工程结构优先）

说明：本阶段不以“行数阈值”作为拆分标准，而以“职责边界清晰、跨域耦合降低、后续扩展稳定”作为判断标准。  
优先队列如下（按执行顺序）：

1. [Done] `js/features/timetable/00-bind-core.js`
- 拆分目标：`匹配索引与身份解析`、`演出实体渲染`、`候选绑定规则`、`快速绑定提交链路`解耦。
- 拟落点：`js/features/timetable/bind/*`（保留 `00-bind-core.js` 兼容壳）。

2. [Done] `js/features/dj/00-library-and-bulk.js`
- 拆分目标：`列表检索与筛选`、`选择状态`、`批量任务编排/轮询`、`日志输出`解耦。
- 拟落点：`js/features/dj/library/*`（保留 `00-library-and-bulk.js` 兼容壳）。

3. [Done] `js/features/import/00-translate-batch.js`
- 拆分目标：`弹窗状态`、`任务队列`、`翻译请求编排`、`结果回写`解耦。
- 拟落点：`js/features/import/translate/*`（保留 `00-translate-batch.js` 兼容壳）。

验收补充：
- 每完成一个文件拆分，必须同步更新 `PLAN/PROGRESS/SPLIT_STRUCTURE_GUIDE/SMOKE_CHECKLIST`。
- 每完成一批，执行一次全量 `node --check` 与函数重名检测。

### 阶段 2.6：关键结构继续收敛（工程标准优先）

说明：仅保留“最影响后续扩展效率”的拆分目标，不按行数机械推进。  
优先队列如下（按执行顺序）：

1. [Done] `js/50-ui-render.js`
- 拆分目标：`筛选面板逻辑`、`月份/年份渲染`、`主列表拼装`解耦，降低 UI 层改动冲突。
- 拟落点：`js/ui/archive/*`（`50-ui-render.js` 逐步收敛为壳层）。

2. [Done] `js/features/archive-row-render.js` + `js/features/event-image-zone-manager.js`
- 拆分目标：将 Event 列表行渲染与图片分区编辑能力收拢到统一 Event 子域，避免跨文件隐式耦合。
- 拟落点：`js/features/event/*`（分为 row/render 与 image/zone 两条子链）。

3. [Done] `js/features/brand/00-brand-admin.js`
- 拆分目标：`列表检索/分页`、`编辑器生命周期`、`媒体上传与回写`解耦。
- 拟落点：`js/features/brand/admin/*`（保留 `00-brand-admin.js` 兼容壳）。

4. [Done] `js/features/dj/profile/00-edit-and-source.js`
- 拆分目标：`基础字段编辑`、`多源候选对比`、`source replace 弹窗状态`解耦。
- 拟落点：`js/features/dj/profile/editor/*`（与 `10-render-and-list-sync.js`、`20-actions-and-modal.js` 形成清晰边界）。

### 阶段 2.7：关键业务模块收口（工程标准优先）

说明：阶段 2.6 已收尾，当前继续按“最关键扩展路径”推进，不追求均匀拆分。  
优先队列如下（按执行顺序）：

1. [Done] `js/features/brand/10-event-brand-binding.js`
- 拆分目标：`筛选检索`、`表格渲染`、`批量绑定动作`解耦。
- 拟落点：`js/features/brand/binding/*`（保留 `10-event-brand-binding.js` 兼容壳）。

2. [Done] `js/features/timetable/11-import-source-compare.js`
- 拆分目标：`字段映射规则`、`对比表渲染`、`候选选择交互`解耦。
- 拟落点：`js/features/timetable/import-compare/*`（保持现有导入链路顺序）。

3. [Done] `js/features/ranking/20-entries-editor.js`
- 拆分目标：`位次行渲染`、`导入匹配`、`保存提交`解耦。
- 拟落点：`js/features/ranking/entries/*`（保留 `20-entries-editor.js` 兼容壳）。

## 阶段 3：状态管理与事件总线收口

- 把散落全局状态收敛到 `store`。
- 将全局事件监听抽离成 `bootstrap` + `bindings`。

阶段 3.1（当前进行中）：

1. [Done] Ranking/Timetable 状态门面首批落地  
- 新增 `js/core/state/00-ranking-state-facade.js` 与 `js/core/state/10-timetable-state-facade.js`。
- `ranking/entries/*` 与 `timetable/import-compare/*` 首批改为通过 facade 读取核心状态。
2. [Done] 收敛 Ranking Board Editor 与 Timetable Modal 直连写入。
- `features/ranking/00-board-editor.js` 改为通过 `getRankingState()` 访问 Ranking 域状态。
- `features/timetable/20-modal-and-render.js` 改为通过 `TimetableStateFacade.modalState()` 访问 Modal 核心状态。
3. [Done] 收敛 Import 主链直连写入。
- 新增 `js/core/state/20-import-state-facade.js`，统一承载 Import Runtime / Translate / Add-Event 状态访问。
- `features/import/runtime/00-search-progress-live.js` 与 `10-transform-persist.js` 切换为通过 Import facade 访问导入运行态。
- `features/import/translate/*` 与 `features/import/20-add-event-modal.js` 切换为通过 Import facade 访问翻译与新增活动态。
4. [Done] 推进事件总线化（启动期 binding + 快捷键 + 弹窗关闭分发首批落地）。
- 新增 `js/core/bootstrap/05-event-bus.js`，提供跨模块轻量事件分发能力。
- `core/bootstrap/20-domcontentloaded-bindings.js` 接入事件总线并集中处理关闭请求与 Lightbox 导航分发。
- `core/bootstrap/30-keyboard-shortcuts.js` 从直连关闭函数改为发出 `ui:request-close` / `lightbox:navigate` 事件。

验收：

- 全局变量数量明显下降。
- 启动流程与状态初始化可追踪。

## 阶段 4：ESM 化与测试化

1. [Done] 为核心纯函数补充首批最小测试集（`node --test`）。
2. [Done] 迁移 ESM 试点（先在纯工具链路验证 `type="module"` 与 import/export）。
3. [Done] 扩大 ESM 覆盖范围（从工具链路扩展到页面启动链路，已完成 keyboard dispatch + keyboard actions）。
4. [Done] 扩大 ESM 覆盖范围（导入/保存等高价值子链路，已完成 import/translate text-plan + import/runtime transform mapper）。
5. [Done] 补充 payload/date 链路自动测试集（lineup sync 与 upsert 相关纯函数）。
6. [Done] 补充 payload/date 链路 ESM 试点（纯函数 import/export + 回归测试）。
7. [Done] 补充 import/translate text-plan 链路 ESM 试点（纯函数 import/export + 回归测试）。
8. [Done] 补充 startup keyboard actions 链路 ESM 试点（纯函数 import/export + 回归测试）。
9. [Done] 补充 import/runtime transform mapper 链路 ESM 试点（纯函数 import/export + 回归测试）。

验收：

- 核心路径具备基础自动验证能力（首批已达成）。
- 支持模块化 import/export（纯工具、启动链路、导入链路高价值子域均已完成首批试点）。
- `lineup sync + payload` 日期链路具备基础自动回归覆盖。
- `lineup sync + payload` 日期链路具备 ESM 试点与自动回归覆盖。
- `import/translate text-plan` 链路具备 ESM 试点与自动回归覆盖。
- `startup keyboard actions` 与 `import/runtime transform mapper` 链路具备 ESM 试点与自动回归覆盖。

---

## 4. 风险与应对

1. 加载顺序风险（高）
- 应对：阶段 1 使用严格顺序 script 标签；不跨越式改写函数名。

2. 内联 `onclick` 对全局函数依赖风险（高）
- 应对：阶段 1 保留函数全局可见；阶段 2 后再引入映射层。

3. 大文件拆分后的回归定位成本（中）
- 应对：按阶段小步提交，配合进度文档记录“变更范围→验证结果”。

4. 浏览器兼容（中）
- 应对：先保持经典脚本模式；ESM 放到后续阶段。

---

## 5. 验收清单（阶段 1）

- [ ] `festival-viewer.html` 不再包含大段内联 CSS/JS。
- [ ] `country-codes-iso3166.js` 仍可正常使用。
- [ ] Event 图片点击放大 + 下载正常。
- [ ] DJ 页面图片点击放大 + 下载正常。
- [ ] Event 编辑弹窗（overlay）与 ESC 关闭正常。
- [ ] 控制台无语法错误。

---

## 6. 进度管理方式

- 以 `MODULAR_REFACTOR_PROGRESS.md` 作为唯一进度真源。
- 每完成一个子步骤立即更新：
  - 状态（Not Started / In Progress / Done）
  - 实际变更文件
  - 验证结果
  - 遗留问题
