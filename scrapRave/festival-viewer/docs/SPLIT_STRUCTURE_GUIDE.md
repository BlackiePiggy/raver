# Festival Viewer 拆分结构文档

更新时间：2026-04-15

## 1. 拆分目标

- 把 `festival-viewer.html` 的单体逻辑拆成可维护、可并行开发的模块。
- 每个文件只负责一个稳定职责域，减少跨域改动带来的回归风险。
- 保持现有 `window` 全局调用兼容（兼容 `onclick` / 旧事件绑定），在不改后端协议的前提下持续演进。

## 2. 拆分策略

1. Shell 化：`festival-viewer.html` 只保留结构和脚本引用，不放大段业务代码。  
2. Core 下沉：全局状态、API、缓存等共用能力收敛到 `js/core/*`。  
3. Feature 分域：按业务域拆分 `js/features/*`，每个域独立演进。  
4. 子域继续拆分：对仍然偏大的域（如 Import、Timetable、Content Admin、DJ、Brand、News）再拆二级模块。  

## 3. 当前目录结构（职责视角）

```text
scrapRave/
  festival-viewer.html                                  # 页面壳 + 脚本加载顺序
  festival-viewer/
    css/
      festival-viewer.css                               # 样式总入口
    js/
      esm/
        core/
          bootstrap/
            keyboard-dispatch.mjs                     # 阶段 4 ESM 启动链路试点（快捷键动作分发）
            keyboard-actions.mjs                      # 阶段 4 ESM 启动链路试点（快捷键动作执行层）
          helpers/
            festival-core-utils.mjs                     # 阶段 4 ESM 试点（纯函数 import/export）
            lineup-sync-payload-utils.mjs               # 阶段 4 ESM 试点（payload/date 纯函数链路）
        features/
          import/
            runtime/
              transform-mapper-utils.mjs                # 阶段 4 ESM 试点（import/runtime 映射纯函数）
            translate/
              text-plan-utils.mjs                       # 阶段 4 ESM 试点（import/translate 文本规划纯函数）
      core/
        00-state-and-api.js                             # 全局状态、常量、API/鉴权
        state/
          00-ranking-state-facade.js                    # Ranking 域状态访问门面
          10-timetable-state-facade.js                  # Timetable 域状态访问门面
          20-import-state-facade.js                     # Import 域状态访问门面
        10-archive-sync-cache.js                        # 兼容壳（已弃用，保留占位）
        archive/
          00-asset-mapping.js                           # 映射与转换（event/lineup/image）
          10-cache-storage-and-meta.js                  # 图片缓存文件与 meta 管理
          20-hydrate-and-load.js                        # 缓存 hydration 与后端加载入口
        20-source-cache-common.js                       # 兼容壳（已弃用，保留占位）
        source-cache/
          00-base-and-idb.js                            # Source cache 基础结构、IDB 与序列化
          10-query-cache-and-logs.js                    # Source cache 查询缓存、头像缓存与日志
          20-avatar-and-display.js                      # Source 缩略头像与展示回退逻辑
        persistence/
          00-idb-handle-store.js                        # 目录句柄持久化与权限检查
          10-folder-selection-bootstrap.js              # 目录选择、恢复与初始化入口
          20-scan-and-loading.js                        # 本地目录扫描与 loading 文案
        helpers/
          00-festival-core-utils.js                     # Festival 通用解析/规范化/格式化
          10-lineup-poster-review.js                    # Lineup 与海报识别弹窗
          20-lineup-sync-and-payload.js                 # 日期对齐与 upsert payload 组装
          30-backend-sync-persist.js                    # Event 图片同步与后端落库
          40-coze-lineup-review.js                      # Coze lineup 识别审核与保存
        save-sync/
          00-collect-and-save.js                        # Event 表单采集、校验与保存编排
          10-header-and-view-render.js                  # Event 卡片头部与详情视图渲染
          20-brand-binding-and-edit-fields.js           # Event↔Brand 编辑联想与表单填充
          30-editor-overlay-lifecycle.js                # Event 编辑器 Overlay 生命周期
        bootstrap/
          00-lightbox-core.js                           # Lightbox 核心渲染与下载流程
          05-event-bus.js                               # 全局轻量事件总线与事件常量
          10-event-dj-image-preview.js                  # Event/DJ 图片点击预览入口
          20-domcontentloaded-bindings.js               # DOMContentLoaded 事件绑定与启动
          25-keyboard-dispatch.js                       # 键盘动作分发优先级与 overlay 状态解析
          30-keyboard-shortcuts.js                      # 全局 ESC 与左右键快捷键
          40-float-nav-hooks.js                         # 浮动导航与页面函数拦截重建
      00-app-core.js                                    # 应用壳：页面切换/入口/头部计数
      10-fs-persistence.js                              # 兼容壳（已弃用，保留占位）
      20-helpers.js                                     # 兼容壳（已弃用，保留占位）
      30-save-sync.js                                   # 兼容壳（已弃用，保留占位）
      40-import.js                                      # Import 状态壳
      50-ui-render.js                                   # 兼容壳（已弃用，保留占位）
      ui/
        archive/
          00-filter-and-match.js                        # 筛选面板、搜索匹配与筛选交互
          10-month-and-render.js                        # 月份 chips 与主列表渲染
          20-build-ui-and-tabs.js                       # Archive UI 入口与年份导航
      60-timetable.js                                   # Timetable 状态壳
      70-lightbox-bootstrap.js                          # 兼容壳（已弃用，保留占位）
      features/
        archive-row-render.js                           # 兼容壳（已弃用，保留占位）
        brand-event-binding.js                          # 兼容壳（已弃用，保留占位）
        dj-management.js                                # 兼容壳（已弃用，保留占位）
        event-image-zone-manager.js                     # 兼容壳（已弃用，保留占位）
        event/
          00-image-zone-manager.js                      # Event 图片分区与草稿管理
          10-archive-row-render.js                      # Archive 卡片/行渲染
        news-admin.js                                   # 兼容壳（已弃用，保留占位）
        ranking-admin.js                                # 兼容壳（已弃用，保留占位）
        ranking-dashboard.js                            # Ranking 展示与榜单加载
        content-admin.js                                # 兼容壳（已弃用，保留占位）
        ranking/
          00-board-editor.js                            # 榜单编辑（新建/更新/删除/封面）
          10-entity-catalog-and-search.js              # 实体目录、检索、自动匹配
          20-entries-editor.js                          # 兼容壳（已弃用，保留占位）
          entries/
            00-normalize-render-and-summary.js          # 位次归一化、汇总与表格渲染
            10-catalog-actions-and-import.js            # 位次行操作、目录回写与文本导入
            20-lifecycle-payload-save.js               # 编辑器生命周期、payload 收集与保存
        brand/
          00-brand-admin.js                             # 兼容壳（已弃用，保留占位）
          admin/
            00-model-grid-loading.js                    # 列表检索、卡片渲染与页面加载刷新
            10-editor-form-lifecycle.js                # 编辑器生命周期与表单草稿同步
            20-media-save-delete.js                    # 媒体上传、保存与删除动作链路
          10-event-brand-binding.js                     # 兼容壳（已弃用，保留占位）
          binding/
            00-source-filter-candidates.js              # Event/Brand 来源筛选与候选收集
            10-table-render-selection.js                # 绑定表格渲染与行级选择交互
            20-actions-batch-page.js                    # 单条/批量绑定动作与分页链路
        news/
          00-model-and-list.js                          # News 解析、筛选、列表渲染
          10-editor-render-media.js                     # 兼容壳（已弃用，保留占位）
          editor/
            00-draft-markdown-resources.js              # 草稿/Markdown/资源库
            10-media-upload.js                          # 媒体上传与封面选择
            20-editor-overlay.js                        # 编辑器弹窗渲染与生命周期
          20-binding-and-crud.js                        # News 绑定、保存删除、加载刷新
        dj/
          00-library-and-bulk.js                        # 兼容壳（已弃用，保留占位）
          library/
            00-search-selection-state.js                # 列表检索、选择模式与工具栏状态
            10-render-and-load.js                       # 列表渲染与库加载刷新
            20-bulk-translate-and-range.js              # 批量双语化任务与索引区间选择
          10-auth.js                                    # 登录鉴权、会话恢复、Auth UI
          20-profile-editor.js                          # 兼容壳（已弃用，保留占位）
          profile/
            00-edit-and-source.js                       # 兼容壳（已弃用，保留占位）
            editor/
              00-basic-fields-and-avatar.js             # 基础字段编辑与头像替换草稿
              10-source-state-compare-fetch.js          # 多源候选状态、对比表与抓取编排
              20-source-modal-lifecycle.js              # source replace 弹窗生命周期
            10-render-and-list-sync.js                  # 详情渲染与列表同步
            20-actions-and-modal.js                     # 保存/删除/双语化/弹窗生命周期
        import/
          00-translate-batch.js                         # 兼容壳（已弃用，保留占位）
          translate/
            00-text-plan-and-merge.js                   # 文本规则/翻译编排/草稿 payload
            10-modal-list-and-editor.js                 # 弹窗筛选列表与草稿编辑
            20-run-and-save.js                          # 批量执行与确认保存
          10-import-runtime.js                          # 兼容壳（已弃用，保留占位）
          runtime/
            00-search-progress-live.js                  # 搜索、进度轮询、实时入库
            10-transform-persist.js                     # 映射、图片下载、落盘与索引重建
            20-festival-file-actions.js                 # 删除活动与打开文件夹
          20-add-event-modal.js                         # 新增活动弹窗
        timetable/
          00-bind-core.js                               # 兼容壳（已弃用，保留占位）
          bind/
            00-match-map-and-identity.js               # DJ 匹配索引与身份解析
            10-musician-render.js                      # 表演实体渲染与快捷绑定入口
            20-bind-state-and-candidates.js            # 绑定状态与候选自动匹配
            30-bind-modal-actions-and-commit.js        # 绑定弹窗动作与快速提交
          10-import-and-prefetch.js                     # 兼容壳（已弃用，保留占位）
          10-import-bind-modal-core.js                  # 导入绑定弹窗核心
          11-import-source-compare.js                   # 兼容壳（已弃用，保留占位）
          import-compare/
            00-normalize-and-field-resolution.js        # 候选归一化与字段值解析
            10-grid-and-compare-render.js               # 来源网格与对比表渲染
            20-selection-actions-and-avatar.js          # 候选选择、批量应用与头像预览
          12-source-cache-prefetch.js                   # 源缓存与预抓取任务
          13-import-fetch-translate-save.js             # 抓取/翻译/入库与头像上传
          20-modal-and-render.js                        # 弹窗编辑与渲染
    docs/
      MODULAR_REFACTOR_PLAN.md                          # 改造路径文档
      MODULAR_REFACTOR_PROGRESS.md                      # 进度追踪文档
      MODULAR_SMOKE_CHECKLIST.md                        # 自动化/手工冒烟记录
      SPLIT_STRUCTURE_GUIDE.md                          # 拆分结构说明
    tests/
      helpers-core-utils.test.js                        # core helpers 首批纯函数测试
      helpers-core-utils-esm.test.mjs                   # ESM 试点模块测试
      keyboard-dispatch-esm.test.mjs                    # 启动链路键盘分发 ESM 试点测试
      keyboard-actions-esm.test.mjs                     # 启动链路键盘动作执行 ESM 试点测试
      helpers-lineup-sync-payload.test.js               # payload/date 链路纯函数测试
      helpers-lineup-sync-payload-esm.test.mjs          # payload/date 链路 ESM 试点测试
      helpers-import-translate-text-plan-esm.test.mjs   # import/translate text-plan ESM 试点测试
      helpers-import-runtime-transform-esm.test.mjs     # import/runtime transform ESM 试点测试
      README.md                                         # 测试执行说明
```

## 4. 近期重点拆分

### 4.1 Content Admin 二次解耦

原文件：`js/features/content-admin.js`（2365 行）  
现状：

- `js/features/news-admin.js`（2 行）
  - 第一层拆分后的兼容壳；后续继续下钻到 `features/news/*`（见 4.4）
- `js/features/ranking-admin.js`（2 行）
  - 第一层拆分后的兼容壳；后续继续下钻到 `features/ranking/*`（见 4.6）
- `js/features/content-admin.js`（3 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。

### 4.2 DJ Management + Library 标准化拆分

原文件：`js/features/dj-management.js`（2216 行）  
现状：

- `js/features/dj/00-library-and-bulk.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。
- `js/features/dj/library/00-search-selection-state.js`（168 行）
  - DJ 检索归一化、字母索引工具
  - 选择模式状态管理与工具栏按钮状态同步
  - 选择集增删、可见项批量选择与基础状态提示
- `js/features/dj/library/10-render-and-load.js`（233 行）
  - DJ 搜索过滤、字母筛选与网格渲染
  - 列表卡片事件绑定（头像/复选框/详情跳转）
  - DJ 全量加载、刷新与头像显示切换
- `js/features/dj/library/20-bulk-translate-and-range.js`（339 行）
  - 批量双语化日志与进度条
  - 任务启动/轮询/停止与结果回填重选
  - 索引区间选择与批量提交编排
- `js/features/dj/10-auth.js`（187 行）
  - Token 规范化、缓存读写
  - 登录弹窗、登录/登出、会话恢复
  - 对外统一 `getViewerAuthHeaders()` 能力
- `js/features/dj/20-profile-editor.js`（2 行）
  - 第一层拆分后的兼容壳；已继续下钻到 `features/dj/profile/*`（见 4.7）
- `js/features/dj-management.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。

### 4.3 Brand/Event-Brand 二次解耦

原文件：`js/features/brand-event-binding.js`（1197 行）  
现状：

- `js/features/brand/00-brand-admin.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。
- `js/features/brand/admin/00-model-grid-loading.js`（248 行）
  - Brand 列表检索、卡片渲染与只读/可编辑态显示
  - Brand 页面加载、刷新与状态栏统计
  - 基础模型规范化（aliases/links/i18n）与查询匹配
- `js/features/brand/admin/10-editor-form-lifecycle.js`（268 行）
  - Brand 编辑器打开/关闭与遮罩交互
  - 表单草稿同步、预览回显与 payload 组装
  - 新建/编辑态切换与按钮禁用态控制
- `js/features/brand/admin/20-media-save-delete.js`（141 行）
  - 头像/封面上传动作
  - Brand 保存与删除动作链路
  - 鉴权失效与失败提示分支
- `js/features/brand/10-event-brand-binding.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。
- `js/features/brand/binding/00-source-filter-candidates.js`（152 行）
  - Event/Brand 来源筛选状态维护与候选池收集
  - 绑定页初始化入口与 datalist 候选更新
  - 关键筛选条件（名称/国家/类型）归一化
- `js/features/brand/binding/10-table-render-selection.js`（170 行）
  - Event↔Brand 绑定表格渲染
  - 行级选择、候选切换与勾选状态同步
  - 分页切换与局部重渲染
- `js/features/brand/binding/20-actions-batch-page.js`（220 行）
  - 单条绑定/解绑动作与结果回写
  - 批量绑定/解绑提交流程与状态提示
  - 分页控制、批次动作与刷新编排
- `js/features/brand-event-binding.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。

### 4.4 News Admin + Editor 二次解耦

原文件：`js/features/news-admin.js`（1379 行）  
现状：

- `js/features/news/00-model-and-list.js`（453 行）
  - News 内容协议解析与编码
  - 筛选/排序/分组与列表渲染
  - 工具栏统计与分组元信息
- `js/features/news/10-editor-render-media.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。
- `js/features/news/editor/00-draft-markdown-resources.js`（291 行）
  - 编辑器草稿渲染与初始化
  - Markdown 预览与资源库交互
  - 资源项插入正文/封面与草稿同步
- `js/features/news/editor/10-media-upload.js`（99 行）
  - 图片选择、拖拽上传与粘贴上传
  - 上传进度状态与失败重试提示
  - 封面媒体选择联动
- `js/features/news/editor/20-editor-overlay.js`（185 行）
  - 编辑器弹窗开关与生命周期
  - 渲染收口（header/toolbar/body/footer）
  - 保存前字段组装与退出保护
- `js/features/news/20-binding-and-crud.js`（353 行）
  - DJ/Brand/Event 绑定检索与写入
  - 保存/删除/快速删除
  - News 列表加载与刷新
- `js/features/news-admin.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。

### 4.5 Timetable Import/Prefetch 二次解耦

原文件：`js/features/timetable/10-import-and-prefetch.js`（1893 行）  
现状：

- `js/features/timetable/10-import-bind-modal-core.js`（379 行）
  - 绑定弹窗开关、Tab 切换、已有 DJ 选择
  - 手动表单读写与基础导入状态同步
- `js/features/timetable/11-import-source-compare.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。
- `js/features/timetable/import-compare/00-normalize-and-field-resolution.js`（283 行）
  - 多源候选归一化（Spotify/Discogs/SoundCloud）
  - 字段来源候选值解析与可用性判定
  - 导入字段选择状态归一化
- `js/features/timetable/import-compare/10-grid-and-compare-render.js`（158 行）
  - 多源候选卡片网格渲染
  - 字段对比表渲染与终值展示
  - 头像来源列渲染与手动上传状态回显
- `js/features/timetable/import-compare/20-selection-actions-and-avatar.js`（162 行）
  - 字段来源切换、头像来源切换与“应用全部”
  - 候选点击后的手动草稿预填逻辑
  - 头像预览刷新与手动头像清理
- `js/features/timetable/12-source-cache-prefetch.js`（454 行）
  - 候选缓存结构、头像缓存、预抓取调度与统计
- `js/features/timetable/13-import-fetch-translate-save.js`（475 行）
  - 在线抓取来源、翻译、Payload 组装
  - 头像上传与最终入库绑定
- `js/features/timetable/10-import-and-prefetch.js`（6 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。

### 4.6 Timetable Bind Core 结构标准化拆分

原文件：`js/features/timetable/00-bind-core.js`（754 行）  
现状：

- `js/features/timetable/bind/00-match-map-and-identity.js`（169 行）
  - DJ 匹配索引构建与重建
  - 名称/别名命中与 ID 规范化
  - 协作艺人（B2B/B3B）解析与身份辅助函数
- `js/features/timetable/bind/10-musician-render.js`（128 行）
  - 表演实体节点渲染（已绑定/未绑定/ID-only）
  - 协作艺人连接符渲染
  - 快捷绑定入口节点事件
- `js/features/timetable/bind/20-bind-state-and-candidates.js`（287 行）
  - 绑定弹窗状态模型（`ttDJBindState`）
  - 绑定候选收集、自动匹配与批量确认
  - 绑定状态文案与绑定单元格渲染
- `js/features/timetable/bind/30-bind-modal-actions-and-commit.js`（170 行）
  - 绑定弹窗动作（搜索更改/清除/状态提示）
  - 快速绑定保存提交链路
  - 行级绑定到 DJ 后的状态回写
- `js/features/timetable/00-bind-core.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。

### 4.7 Ranking Admin 二次解耦

原文件：`js/features/ranking-admin.js`（985 行）  
现状：

- `js/features/ranking/00-board-editor.js`（304 行）
  - 榜单切换与年份切换入口
  - 榜单编辑器（新增/编辑/删除）
  - 榜单封面上传、保存与关闭流程
  - 通过 `getRankingState()` 访问 Ranking 域状态
- `js/features/ranking/10-entity-catalog-and-search.js`（199 行）
  - Brand/DJ 实体目录构建
  - Name/ID 解析与自动匹配规则
  - 输入联想检索、datalist 刷新与检索节流
- `js/features/ranking/20-entries-editor.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。
- `js/features/ranking/entries/00-normalize-render-and-summary.js`（198 行）
  - 位次归一化、匹配统计与摘要渲染
  - 未匹配聚类/按 Rank 视图渲染
  - 位次行表格渲染与基础输入联动
- `js/features/ranking/entries/10-catalog-actions-and-import.js`（150 行）
  - 导入 DJ 后目录回写与行级绑定
  - 行增删、插入、单条/批量自动匹配
  - 文本导入解析与自动绑定回填
- `js/features/ranking/entries/20-lifecycle-payload-save.js`（150 行）
  - 编辑器打开/关闭与 Overlay 生命周期
  - payload 收集与校验
  - 保存提交流程与刷新回写
- `js/features/ranking-admin.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。

### 4.8 DJ Profile 二次解耦

原文件：`js/features/dj/20-profile-editor.js`（1289 行）  
现状：

- `js/features/dj/profile/00-edit-and-source.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。
- `js/features/dj/profile/editor/00-basic-fields-and-avatar.js`（121 行）
  - 编辑器基础字段格式化与状态提示
  - 头像上传草稿选择、预览与清空
  - 编辑区头像上传器 UI 刷新
- `js/features/dj/profile/editor/10-source-state-compare-fetch.js`（467 行）
  - 多源替换状态模型与字段来源选择策略
  - Spotify/Discogs/SoundCloud 候选抓取与结果归档
  - 字段对比表渲染、按字段应用与“应用全部”
- `js/features/dj/profile/editor/20-source-modal-lifecycle.js`（61 行）
  - Source Replace 弹窗初始化与开关生命周期
  - Source toggle 变化后的状态归一化
  - Overlay 点击关闭行为
- `js/features/dj/profile/10-render-and-list-sync.js`（314 行）
  - DJ 资料页内容渲染（Profile/Sets/Events/Social）
  - 列表内 DJ 项同步与删除后的本地状态更新
  - 编辑动作按钮绑定与禁用态管理
- `js/features/dj/profile/20-actions-and-modal.js`（328 行）
  - 一键双语化、保存、删除动作链路
  - Profile 打开/关闭与 Overlay 事件
  - 保存后回写渲染与头像替换收口
- `js/features/dj/20-profile-editor.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。

### 4.9 Core Archive 同步域二次解耦

原文件：`js/core/10-archive-sync-cache.js`（680 行）  
现状：

- `js/core/archive/00-asset-mapping.js`（327 行）
  - Event 图片分区映射、文件名推导
  - Lineup slot 到 Archive 行格式转换
  - 后端 Event 到前端 Festival 结构映射
- `js/core/archive/10-cache-storage-and-meta.js`（265 行）
  - 缓存目录句柄、文件读写、meta 读写
  - blob URL 生命周期管理
  - 远程图片下载、缓存 reconcile 与对象 URL 生成
- `js/core/archive/20-hydrate-and-load.js`（88 行）
  - 单行图片 hydration（缓存命中/回退远程）
  - `loadArchiveEventsFromBackend` 全量加载入口
- `js/core/10-archive-sync-cache.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。

### 4.10 Import Runtime 二次解耦

原文件：`js/features/import/10-import-runtime.js`（750 行）  
现状：

- `js/features/import/runtime/00-search-progress-live.js`（435 行）
  - 搜索结果渲染与勾选
  - 抓取进度轮询与 UI 展示
  - 实时入库队列与状态汇总
- `js/features/import/runtime/10-transform-persist.js`（333 行）
  - 抓取数据映射到 `info.json`
  - 图片下载与落盘
  - 入库写入、索引重建、结果汇总
- `js/features/import/runtime/20-festival-file-actions.js`（99 行）
  - 活动删除（后端/本地）链路
  - 文件夹打开与状态提示
- `js/features/import/10-import-runtime.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。
- `js/core/state/20-import-state-facade.js`（163 行）
  - Import Runtime/Translate/Add-Event 域状态门面
  - 历史全局状态的 getter/setter 代理与兼容访问

### 4.11 Core Source Cache 二次解耦

原文件：`js/core/20-source-cache-common.js`（361 行）  
现状：

- `js/core/source-cache/00-base-and-idb.js`（93 行）
  - Source cache 数据结构与默认值
  - IndexedDB open/get/set 基础封装
  - Source payload 序列化与反序列化
- `js/core/source-cache/10-query-cache-and-logs.js`（198 行）
  - Source 查询缓存命中与回填
  - 头像 URL 缓存与过期策略
  - 统计日志与故障回退记录
- `js/core/source-cache/20-avatar-and-display.js`（70 行）
  - Source 头像缩略图优先级
  - 缺图占位与展示回退
  - 详情页头像映射辅助
- `js/core/20-source-cache-common.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。

### 4.12 Core Persistence 二次解耦

原文件：`js/10-fs-persistence.js`（294 行）  
现状：

- `js/core/persistence/00-idb-handle-store.js`（100 行）
  - 目录句柄持久化支持探测
  - IndexedDB 打开/get/put/delete 封装
  - 句柄保存/恢复/清理与权限检查
- `js/core/persistence/10-folder-selection-bootstrap.js`（104 行）
  - 当前目录路径显示与未选中态重置
  - 手动选择目录与清除记忆目录
  - 启动时自动恢复目录与加载入口
- `js/core/persistence/20-scan-and-loading.js`（89 行）
  - 本地目录年/月遍历与节日结构构建
  - `info.json` 解析与图片分类挂载
  - loading 细节文案更新
- `js/10-fs-persistence.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。

### 4.13 Core Helpers 二次解耦

原文件：`js/20-helpers.js`（2151 行）  
现状：

- `js/core/helpers/00-festival-core-utils.js`（438 行）
  - Festival 解析、i18n 归一化、社媒/链接拆分
  - festivalId 生成与基础格式化工具
  - 权限检查、lineup 归一化与图片挑选基础函数
- `js/core/helpers/10-lineup-poster-review.js`（498 行）
  - Lineup 去重与合并
  - 海报识别弹窗状态、聚合字段与回填交互
  - 编辑面板字段写入与状态提示
- `js/core/helpers/20-lineup-sync-and-payload.js`（448 行）
  - 日期/时间对齐与 festivalDayIndex 计算
  - 后端 imageAssets 解析与主图选择
  - Event upsert payload 组装
- `js/core/helpers/30-backend-sync-persist.js`（386 行）
  - Event 图片上传/缓存同步与失败收集
  - 后端 events 创建/更新与二次 patch
  - 本地 info.json 持久化与后端回写
- `js/core/helpers/40-coze-lineup-review.js`（383 行）
  - Coze lineup 识别弹窗状态与结果表编辑
  - 识别批处理、去重追加与日期规范化
  - 识别结果确认保存与 UI 回写
- `js/20-helpers.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。

### 4.14 Save Sync 二次解耦

原文件：`js/30-save-sync.js`（551 行）  
现状：

- `js/core/save-sync/00-collect-and-save.js`（123 行）
  - Event 编辑表单字段采集与校验
  - payload 规范化与 festivalId 兜底
  - 保存动作主编排（本地 + 后端）与结果提示
- `js/core/save-sync/10-header-and-view-render.js`（231 行）
  - Event 卡片头部展示刷新
  - 详情区域（基本信息/链接/社媒/描述）渲染
  - 票务信息与来源信息格式化展示
- `js/core/save-sync/20-brand-binding-and-edit-fields.js`（148 行）
  - Event↔Brand 搜索 token 与候选筛选
  - Brand datalist 联想与显式选择绑定
  - 编辑表单回填与字段初始化
- `js/core/save-sync/30-editor-overlay-lifecycle.js`（47 行）
  - Event 编辑器打开/关闭生命周期
  - Overlay 点击关闭与焦点收敛
  - 多面板编辑互斥控制
- `js/30-save-sync.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。

### 4.15 Bootstrap 二次解耦

原文件：`js/70-lightbox-bootstrap.js`（702 行）  
现状：

- `js/core/bootstrap/00-lightbox-core.js`（252 行）
  - Lightbox item 规范化、缩略图分组、主图渲染
  - 图片下载（代理拉取、命名、Blob 下载）
  - Lightbox 打开/关闭与前后切换
- `js/core/bootstrap/05-event-bus.js`（65 行）
  - `on/off/emit/once` 轻量事件总线
  - 全局事件常量统一定义（app/lightbox/ui close request）
  - 跨模块低耦合事件传递入口
- `js/core/bootstrap/10-event-dj-image-preview.js`（82 行）
  - Event/DJ 场景图片点击预览拦截
  - 预览分组收集、标题推断与起始索引计算
  - 从 DOM 图片节点构造 lightbox item
- `js/core/bootstrap/20-domcontentloaded-bindings.js`（275 行）
  - 页面各域 input/change/keydown 事件绑定
  - DJ/News/Timetable/Auth 等启动时交互初始化
  - 鉴权恢复与应用启动入口调度
  - 响应事件总线 close/navigate 请求并集中分发关闭动作
- `js/core/bootstrap/25-keyboard-dispatch.js`（71 行）
  - 键盘动作优先级表（close priority）维护
  - overlay 开启状态读取与动作判定（close / navigate）
  - 为快捷键层提供纯决策分发能力
- `js/core/bootstrap/30-keyboard-shortcuts.js`（71 行）
  - 键盘事件采集与状态收集
  - 通过 `keyboard-dispatch` 决策动作并转发到事件总线
  - 保留 fallback 执行路径确保兼容
- `js/core/bootstrap/40-float-nav-hooks.js`（124 行）
  - 浮动导航展开/固定/滚动定位逻辑
  - 导航列表构建与空态渲染
  - `buildUI/renderYear/switchAppPage` 拦截后自动重建导航
- `js/70-lightbox-bootstrap.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。

### 4.16 Import Translate Batch 结构标准化拆分

原文件：`js/features/import/00-translate-batch.js`（722 行）  
现状：

- `js/features/import/translate/00-text-plan-and-merge.js`（243 行）
  - 中英文文本规则与双语字段解析
  - Festival 翻译请求 payload 构建与 Coze 请求编排
  - 草稿 payload 组装、落盘入口与状态基础函数
- `js/features/import/translate/10-modal-list-and-editor.js`（360 行）
  - 批量翻译弹窗生命周期（打开/关闭/遮罩点击）
  - 年份筛选、活动列表渲染、状态呈现
  - 翻译草稿编辑、勾选与批量选择交互
- `js/features/import/translate/20-run-and-save.js`（157 行）
  - 批量翻译执行队列与进度推进
  - 自动写入模式与确认保存模式分流
  - 保存后索引重建与结果状态汇总
- `js/features/import/00-translate-batch.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。

### 4.17 UI Render Core 结构标准化拆分

原文件：`js/50-ui-render.js`（830 行）  
现状：

- `js/ui/archive/00-filter-and-match.js`（261 行）
  - 国家/活动类型筛选 key 归一化与选项汇总
  - 筛选面板开关、勾选交互与清空逻辑
  - 搜索命中判断、筛选汇总判定与 `escapeHtml`
- `js/ui/archive/10-month-and-render.js`（99 行）
  - 月份 chips 构建与月份选择态维护
  - 年份分组渲染、global search 年度聚合渲染
  - 主列表空态回退与 `buildRow` 装配入口
- `js/ui/archive/20-build-ui-and-tabs.js`（74 行）
  - `buildUI` 入口编排（导航、搜索、筛选、初始化）
  - 年份 Tab 渲染与切换绑定
  - 视图恢复参数下的 UI 状态还原
- `js/50-ui-render.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。

### 4.18 Event 列表与图片编辑子域收拢

原文件：
- `js/features/archive-row-render.js`（396 行）
- `js/features/event-image-zone-manager.js`（419 行）  
现状：

- `js/features/event/00-image-zone-manager.js`（419 行）
  - Event 已存在图片草稿化、分区改类与删除跟踪
  - 分区上传队列、拖拽/选择上传交互与 payload 汇总
  - 后端事件回写 patch 与分区卡片 HTML 组装
- `js/features/event/10-archive-row-render.js`（396 行）
  - Archive 行 UI 组装与信息面板渲染
  - Event 编辑器/Timetable 按钮与删除入口绑定
  - Event 图片分区编辑面板挂载与草稿状态联动
- `js/features/archive-row-render.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。
- `js/features/event-image-zone-manager.js`（2 行）
  - 仅保留兼容壳注释，避免旧路径失效导致误删风险。

### 4.19 ESM 试点（阶段 4）

现状：

- `js/esm/core/helpers/festival-core-utils.mjs`（180 行）
  - 从 core helpers 中抽取纯函数 ESM 试点
  - 提供标准 import/export（不改现有页面经典脚本链路）
  - 用于后续逐步 ESM 化迁移验证
- `tests/helpers-core-utils-esm.test.mjs`（77 行）
  - ESM 模块自动测试
  - 与 CommonJS 测试共同作为阶段 4 回归基座
- `js/esm/core/bootstrap/keyboard-dispatch.mjs`（75 行）
  - 启动链路快捷键动作分发 ESM 试点
  - 提供 close priority、overlay 状态映射与动作判定函数
- `tests/keyboard-dispatch-esm.test.mjs`（48 行）
  - 启动链路 ESM 试点自动测试
  - 覆盖 close priority、lightbox 导航与状态映射
- `js/esm/core/bootstrap/keyboard-actions.mjs`（33 行）
  - 启动链路快捷键动作执行层 ESM 试点
  - 提供 close/navigate 执行适配与方向归一化
- `tests/keyboard-actions-esm.test.mjs`（54 行）
  - 启动链路动作执行层 ESM 自动测试
  - 覆盖 close fallback 桥接与 lightbox 导航执行
- `tests/helpers-lineup-sync-payload.test.js`（180 行）
  - payload/date 链路自动测试
  - 覆盖日期解析、day rollover、slot 生成与图片资产归一化
- `js/esm/core/helpers/lineup-sync-payload-utils.mjs`（333 行）
  - payload/date 链路 ESM 试点
  - 提供日期解析、slot 生成、图片资产归一化的 import/export 能力
- `tests/helpers-lineup-sync-payload-esm.test.mjs`（84 行）
  - payload/date 链路 ESM 自动测试
  - 覆盖日期解析、slot 生成与图片资产归一化
- `js/esm/features/import/translate/text-plan-utils.mjs`（79 行）
  - 导入链路 `import/translate` 文本规划纯函数 ESM 试点
  - 提供双语字段就绪判定、局部翻译合并与计划请求构建
- `tests/helpers-import-translate-text-plan-esm.test.mjs`（75 行）
  - 导入链路 `import/translate` 文本规划 ESM 自动测试
  - 覆盖字符判定、双语合并、translate key 与计划构建
- `js/esm/features/import/runtime/transform-mapper-utils.mjs`（167 行）
  - 导入链路 `import/runtime` 映射纯函数 ESM 试点
  - 提供抓取时间解析、来源数据归一化与导入信息映射
- `tests/helpers-import-runtime-transform-esm.test.mjs`（82 行）
  - 导入链路 `import/runtime` 映射 ESM 自动测试
  - 覆盖抓取字段清洗、国家提取、lineup 映射与链接去重

## 5. 关键依赖与加载顺序

`festival-viewer.html` 当前顺序：

1. `core/00-state-and-api.js`
2. `core/state/00-ranking-state-facade.js` + `core/state/20-import-state-facade.js`
3. `core/archive/*`
4. `core/source-cache/*`
5. `00-app-core.js`
6. `features/brand/admin/*`
7. `features/brand/binding/*`
8. `features/news/00-model-and-list.js`
9. `features/news/editor/*`
10. `features/news/20-binding-and-crud.js`
11. `features/ranking/*`
12. `features/ranking-dashboard.js`
13. `core/persistence/*`
14. `core/helpers/*`
15. `core/save-sync/*`
16. 其余基础模块（`40-import.js`、`ui/archive/*`、`60-timetable.js`）
17. `features/import/*`
18. `features/event/*` + `ui/archive/*`
19. `features/timetable/bind/*` + `core/state/10-timetable-state-facade.js` + `features/timetable/import*`
20. `features/dj/library/*` + `features/dj/10-auth.js`
21. `features/dj/profile/editor/*` + `features/dj/profile/10-render-and-list-sync.js` + `20-actions-and-modal.js`
22. `core/bootstrap/*`（最终绑定与启动）

说明：`ranking-dashboard.js` 依赖 `features/ranking/00-board-editor.js` 提供的 `onRankingBoardChanged/onRankingYearChanged`，因此必须后加载。
说明：DJ Profile 子链路需保持 `features/dj/profile/editor/00-basic-fields-and-avatar.js -> 10-source-state-compare-fetch.js -> 20-source-modal-lifecycle.js -> 10-render-and-list-sync.js -> 20-actions-and-modal.js`。
说明：Core Archive 子链路需保持 `core/archive/00-asset-mapping.js -> 10-cache-storage-and-meta.js -> 20-hydrate-and-load.js`。
说明：Core Source Cache 子链路需保持 `core/source-cache/00-base-and-idb.js -> 10-query-cache-and-logs.js -> 20-avatar-and-display.js`。
说明：Core Persistence 子链路需保持 `core/persistence/00-idb-handle-store.js -> 10-folder-selection-bootstrap.js -> 20-scan-and-loading.js`。
说明：Core Helpers 子链路需保持 `core/helpers/00-festival-core-utils.js -> 10-lineup-poster-review.js -> 20-lineup-sync-and-payload.js -> 30-backend-sync-persist.js -> 40-coze-lineup-review.js`。
说明：Save Sync 子链路需保持 `core/save-sync/00-collect-and-save.js -> 10-header-and-view-render.js -> 20-brand-binding-and-edit-fields.js -> 30-editor-overlay-lifecycle.js`。
说明：Bootstrap 子链路需保持 `core/bootstrap/00-lightbox-core.js -> 05-event-bus.js -> 10-event-dj-image-preview.js -> 20-domcontentloaded-bindings.js -> 25-keyboard-dispatch.js -> 30-keyboard-shortcuts.js -> 40-float-nav-hooks.js`。
说明：Timetable Bind 子链路需保持 `features/timetable/bind/00-match-map-and-identity.js -> 10-musician-render.js -> 20-bind-state-and-candidates.js -> 30-bind-modal-actions-and-commit.js`。
说明：Timetable Import Compare 子链路需保持 `features/timetable/import-compare/00-normalize-and-field-resolution.js -> 10-grid-and-compare-render.js -> 20-selection-actions-and-avatar.js`。
说明：Ranking Entries 子链路需保持 `features/ranking/entries/00-normalize-render-and-summary.js -> 10-catalog-actions-and-import.js -> 20-lifecycle-payload-save.js`。
说明：DJ Library 子链路需保持 `features/dj/library/00-search-selection-state.js -> 10-render-and-load.js -> 20-bulk-translate-and-range.js`。
说明：News Editor 子链路需保持 `features/news/editor/00-draft-markdown-resources.js -> 10-media-upload.js -> 20-editor-overlay.js`。
说明：Import Runtime 子链路需保持 `features/import/runtime/00-search-progress-live.js -> 10-transform-persist.js -> 20-festival-file-actions.js`。
说明：Import Translate 子链路需保持 `features/import/translate/00-text-plan-and-merge.js -> 10-modal-list-and-editor.js -> 20-run-and-save.js`。
说明：UI Archive 子链路需保持 `ui/archive/00-filter-and-match.js -> 10-month-and-render.js -> 20-build-ui-and-tabs.js`。
说明：Event 子链路需保持 `features/event/00-image-zone-manager.js -> 10-archive-row-render.js`。
说明：Brand Admin 子链路需保持 `features/brand/admin/00-model-grid-loading.js -> 10-editor-form-lifecycle.js -> 20-media-save-delete.js`。
说明：Brand Binding 子链路需保持 `features/brand/binding/00-source-filter-candidates.js -> 10-table-render-selection.js -> 20-actions-batch-page.js`。
说明：`js/esm/*` 当前为阶段 4 试点链路，不参与 `festival-viewer.html` 运行时加载顺序，仅用于 import/export 验证与测试。

## 6. 各文件扩展边界（新增功能时怎么放）

- News 内容协议/列表筛选：放 `features/news/00-model-and-list.js`。
- News 草稿/Markdown/资源库：放 `features/news/editor/00-draft-markdown-resources.js`。
- News 媒体上传与封面选择：放 `features/news/editor/10-media-upload.js`。
- News 编辑器弹窗生命周期：放 `features/news/editor/20-editor-overlay.js`。
- News 绑定与 CRUD：放 `features/news/20-binding-and-crud.js`。
- Ranking 榜单编辑相关：放 `features/ranking/00-board-editor.js`。
- Ranking 匹配与检索策略：放 `features/ranking/10-entity-catalog-and-search.js`。
- Ranking 位次编辑与导入流程：放 `features/ranking/entries/*`。
- Ranking 展示样式或加载策略：放 `ranking-dashboard.js`。
- Brand 列表检索、卡片渲染、加载刷新：放 `features/brand/admin/00-model-grid-loading.js`。
- Brand 编辑器生命周期与表单草稿：放 `features/brand/admin/10-editor-form-lifecycle.js`。
- Brand 媒体上传与保存删除动作：放 `features/brand/admin/20-media-save-delete.js`。
- Event↔Brand 绑定和批量操作：放 `features/brand/binding/*`。
- DJ 列表筛选/选择态：放 `features/dj/library/00-search-selection-state.js`。
- DJ 列表渲染与加载：放 `features/dj/library/10-render-and-load.js`。
- DJ 批量任务与索引区间：放 `features/dj/library/20-bulk-translate-and-range.js`。
- 鉴权/登录行为：放 `features/dj/10-auth.js`。
- DJ 编辑器基础字段与头像替换草稿：放 `features/dj/profile/editor/00-basic-fields-and-avatar.js`。
- DJ 多源候选状态、抓取与对比：放 `features/dj/profile/editor/10-source-state-compare-fetch.js`。
- DJ source replace 弹窗生命周期：放 `features/dj/profile/editor/20-source-modal-lifecycle.js`。
- DJ 详情渲染与列表状态同步：放 `features/dj/profile/10-render-and-list-sync.js`。
- DJ 保存/删除/双语化与弹窗生命周期：放 `features/dj/profile/20-actions-and-modal.js`。
- Import 搜索/进度/实时入库：放 `features/import/runtime/00-search-progress-live.js`。
- Import 映射/落盘/索引重建：放 `features/import/runtime/10-transform-persist.js`。
- Import 删除/打开文件夹动作：放 `features/import/runtime/20-festival-file-actions.js`。
- Import 翻译规则与 payload 编排：放 `features/import/translate/00-text-plan-and-merge.js`。
- Import 翻译弹窗列表与草稿编辑：放 `features/import/translate/10-modal-list-and-editor.js`。
- Import 批量执行与确认保存：放 `features/import/translate/20-run-and-save.js`。
- ESM 试点模块：放 `js/esm/core/**/*.mjs`（先不接入运行时脚本链路）。
- 纯函数与启动链路试点回归测试：放 `tests/*.test.js`（当前首批含 `tests/helpers-core-utils.test.js` 与 `tests/keyboard-dispatch-esm.test.mjs`）。
- Archive 筛选面板与搜索匹配：放 `ui/archive/00-filter-and-match.js`。
- Archive 年月分组渲染：放 `ui/archive/10-month-and-render.js`。
- Archive UI 启动编排与年份导航：放 `ui/archive/20-build-ui-and-tabs.js`。
- Event 图片分区管理与上传草稿：放 `features/event/00-image-zone-manager.js`。
- Event 行渲染与详情面板挂载：放 `features/event/10-archive-row-render.js`。
- Timetable 绑定逻辑变更：优先放 `features/timetable/bind/*`。
- Timetable 导入弹窗核心：放 `features/timetable/10-import-bind-modal-core.js`。
- Timetable 来源对比/来源切换：放 `features/timetable/import-compare/*`。
- Timetable 预抓取与缓存：放 `features/timetable/12-source-cache-prefetch.js`。
- Timetable 抓取/翻译/入库：放 `features/timetable/13-import-fetch-translate-save.js`。
- Archive 映射与缓存加载：优先放 `core/archive/*`；跨域通用函数优先评估放 `core/helpers/*`。
- Source 查询缓存、头像缓存与展示回退：优先放 `core/source-cache/*`。
- 目录句柄持久化与目录扫描：优先放 `core/persistence/*`。
- Festival 解析/规范化工具：优先放 `core/helpers/00-festival-core-utils.js`。
- 海报识别与回填交互：优先放 `core/helpers/10-lineup-poster-review.js`。
- 日期对齐与 payload 组装：优先放 `core/helpers/20-lineup-sync-and-payload.js`。
- 后端同步与本地持久化：优先放 `core/helpers/30-backend-sync-persist.js`。
- Coze 识别审核流程：优先放 `core/helpers/40-coze-lineup-review.js`。
- Event 表单采集与保存编排：优先放 `core/save-sync/00-collect-and-save.js`。
- Event 详情与头部展示回写：优先放 `core/save-sync/10-header-and-view-render.js`。
- Event↔Brand 编辑联想与回填：优先放 `core/save-sync/20-brand-binding-and-edit-fields.js`。
- Event 编辑器 Overlay 生命周期：优先放 `core/save-sync/30-editor-overlay-lifecycle.js`。
- Lightbox 核心渲染与下载：优先放 `core/bootstrap/00-lightbox-core.js`。
- 全局事件总线与事件常量：优先放 `core/bootstrap/05-event-bus.js`。
- Event/DJ 图片点击预览入口：优先放 `core/bootstrap/10-event-dj-image-preview.js`。
- 启动期 DOM 事件绑定：优先放 `core/bootstrap/20-domcontentloaded-bindings.js`。
- 键盘动作分发优先级与状态决策：优先放 `core/bootstrap/25-keyboard-dispatch.js`。
- 全局 ESC/方向键快捷键：优先放 `core/bootstrap/30-keyboard-shortcuts.js`。
- 浮动导航与页面钩子：优先放 `core/bootstrap/40-float-nav-hooks.js`。
- 状态/API 入口：放 `core/00-state-and-api.js`。
- Ranking 域状态访问入口：放 `core/state/00-ranking-state-facade.js`。
- Timetable 域状态访问入口：放 `core/state/10-timetable-state-facade.js`。
- Import 域状态访问入口：放 `core/state/20-import-state-facade.js`。

## 7. 持续改造建议

1. 已完成 `ranking/00-board-editor.js`、`timetable/20-modal-and-render.js`、`import/runtime/*`、`import/translate/*`、`import/20-add-event-modal.js` 的 facade 状态接入。  
2. 已完成事件总线首批落地（启动期 binding + 快捷键 + 弹窗关闭分发）；下一步可按需继续把更多跨域动作事件化。  
3. 已落地 ESM 试点（`js/esm/core/helpers/festival-core-utils.mjs` + `js/esm/core/bootstrap/keyboard-dispatch.mjs` + `js/esm/core/bootstrap/keyboard-actions.mjs` + `js/esm/core/helpers/lineup-sync-payload-utils.mjs` + `js/esm/features/import/translate/text-plan-utils.mjs` + `js/esm/features/import/runtime/transform-mapper-utils.mjs`）与八测试入口。  
4. 已补齐 payload/date 链路测试（CommonJS + ESM），覆盖 lineup sync 核心纯函数。  
5. 已补齐 import/translate text-plan 与 import/runtime transform 链路 ESM 测试，覆盖导入映射关键纯函数。  
6. 下一步转入手工冒烟与阶段验收收口。  
7. 保持“每次拆分 + 一次全量 `node --check` + `node --test ...` + 进度文档更新”的节奏，降低回归风险。  
