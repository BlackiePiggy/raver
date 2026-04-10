# iOS 增量功能开发规范（MVVM + Coordinator）

Last Updated: 2026-04-10  
Owner: iOS maintainers + Codex

## 1. 目的

这份文档用于规范你后续每一次“增量加功能”的开发路径，确保在现有 `MVVM + Coordinator` 架构下：

- 功能可持续扩展，不回退成混合架构。
- 导航一致（push-first + allowlist modal）。
- 依赖注入一致（`AppContainer` 驱动）。
- 任何新 agent 都能按同一套流程接手。

---

## 2. 适用范围

适用于以下增量需求：

- 新页面、新子流程、新入口按钮。
- 既有页面增加新业务状态、异步加载、编辑保存。
- 新的路由跳转、跨模块跳转。
- 新增接口对接、仓库/用例扩展。

---

## 3. 架构硬规则（必须遵守）

### 3.1 分层职责

- `View`：只负责渲染和转发用户意图。
- `ViewModel`：负责页面状态、异步任务、状态转换。
- `Coordinator`：负责导航路径和目的地拼装。
- `Repository/UseCase`：负责业务流程与数据编排。
- `Service`：负责原始 API 调用与底层读写。

### 3.2 依赖注入

- 禁止在 Feature View 内直接调用 `AppEnvironment.makeService/makeWebService`。
- 依赖必须从 `AppContainer` 或构造器注入。
- 禁止恢复 `appState.service` 服务定位器式访问。

### 3.3 导航策略

- 默认 `push-first`。
- `sheet/fullScreenCover` 仅允许用于：
- 系统分享、短时工具面板、沉浸式预览/播放器（并且要在 allowlist 中）。
- 新增 modal 前，先评估是否可以改为 coordinator push。

### 3.4 状态边界

- Feature 状态放在 `ViewModel`，不放 `AppState`。
- `AppState` 仅保留全局状态：会话、语言、全局错误、未读数等。

---

## 4. 每次增量开发的标准流程

## Step 0: 需求归类（先做再写代码）

- 归类为 `新流程` / `已有流程扩展` / `仅 UI 调整`。
- 确认入口模块（Discover/Circle/Messages/Profile/跨入口）。
- 确认是否新增路由、是否新增仓库接口、是否新增用例。

输出：

- 一句目标描述。
- 一句非目标描述（避免范围蔓延）。

## Step 1: 路由设计（Coordinator 先行）

- 若有新跳转，先定义 route case（对应 Feature Coordinator）。
- 在 coordinator 目的地 switch 中补齐 destination。
- 通过环境 closure（如 `discoverPush`）从 view 触发跳转。

检查：

- 不在 view 里堆本地路由状态替代 coordinator（除纯局部临时子页面）。

## Step 2: 数据与业务边界设计

- 先判断现有 repository 是否可复用。
- 可复用：扩展 repository protocol + adapter。
- 不可复用：新增 repository 边界（必要时再拆 use case）。
- 跨多个 service 调用的流程优先抽 use case。

检查：

- ViewModel 不应直接拼装复杂多调用业务流程（应迁移到 use case）。

## Step 3: ViewModel 实现

- 新增或扩展 ViewModel：
- 输入：用户意图方法（`load()`, `refresh()`, `submit()` 等）。
- 输出：`@Published` 页面状态。
- 用 `@MainActor` 保证 UI 发布线程安全。
- 处理 loading/error/empty 状态。

检查：

- View 不直接写网络逻辑。
- 错误信息统一可用户展示（`userFacingMessage`）。

## Step 4: View 接线

- View 只绑定状态和触发事件。
- 复杂视图使用 Root 容器组装依赖（`<Domain>RootView -> ScreenView(viewModel:)`）。
- 减少非必要本地状态，保留纯 UI 临时状态即可。

## Step 5: 导航策略确认

- 默认 push。
- 若使用 sheet/fullScreenCover，必须满足 allowlist 语义。
- 若新增 modal，必须同步更新：
- `scripts/modal-allowlist-signatures.txt`
- `docs/MVVM_COORDINATOR_MIGRATION_PLAN.md` 的 P9.4 rationale。

## Step 6: 文档更新（必须）

功能完成后至少更新以下文档中受影响项：

- `docs/MVVM_COORDINATOR_MIGRATION_PLAN.md`
- 若新增/变更跳转链路：`docs/IOS_MANUAL_NAVIGATION_CLICKPATH_CHECKLIST.md`
- 若影响发布冒烟路径：`docs/IOS_RELEASE_SMOKE_RUNBOOK.md`

## Step 7: 质量闸门（必须全部通过）

在仓库根目录执行：

```bash
scripts/run-coordinator-hardening-preflight.sh
```

```bash
xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build
```

如果新增/调整 modal allowlist：

```bash
scripts/check-modal-allowlist.sh --write-allowlist
scripts/check-modal-allowlist.sh
```

---

## 5. 增量开发完成定义（DoD）

一次增量需求只有在以下全部满足时才算完成：

- 编译通过。
- 路由归属清晰（coordinator-owned）。
- View 无直接 service factory 调用。
- ViewModel 承载业务状态与异步流程。
- 文档已更新（迁移计划 + 回归清单按需更新）。
- 冒烟路径可复现且通过。

---

## 6. 禁止事项（红线）

- 在 Feature View 中新增 `AppEnvironment.makeService/makeWebService`。
- 新增跨模块业务流程时直接放在 View 里写多段网络调用。
- 遇到导航问题用更多 `sheet/fullScreenCover` 临时绕过 coordinator。
- 将非全局状态塞进 `AppState`。
- 未更新文档直接结束任务。

---

## 7. 推荐的最小增量模板

## 7.1 新增一个业务页面（有数据、有跳转）

1. 定义 route case。  
2. coordinator destination 接上页面。  
3. 建/改 repository 接口。  
4. 建 ViewModel（`@MainActor` + loading/error）。  
5. RootView 注入依赖并创建 ViewModel。  
6. ScreenView 绑定状态，触发 route push。  
7. 跑 preflight + build。  
8. 更新迁移计划和回归清单。  

## 7.2 给现有页面加功能（如搜索/筛选/编辑）

1. 先扩 ViewModel，不先改 View。  
2. 评估是否要扩 repository/use case。  
3. 若有新跳转，先改 coordinator route。  
4. View 仅绑定新状态与事件。  
5. 跑 preflight + build。  
6. 更新文档与手工回归路径。  

---

## 8. 提交前检查清单（可直接复制到 PR 描述）

- [ ] 路由通过对应 coordinator 管理（无临时分叉导航）。
- [ ] View 未新增 service factory 调用。
- [ ] ViewModel 承载业务状态与异步逻辑。
- [ ] 新增 modal 已评估 push-first，并完成 allowlist/rationale 更新（如适用）。
- [ ] `scripts/run-coordinator-hardening-preflight.sh` 通过。
- [ ] `xcodebuild ... build` 通过。
- [ ] `MVVM_COORDINATOR_MIGRATION_PLAN.md` 已更新。
- [ ] `IOS_MANUAL_NAVIGATION_CLICKPATH_CHECKLIST.md` 已更新（如跳转变更）。

---

## 9. 与现有文档的关系

- 架构主线与阶段状态：`docs/MVVM_COORDINATOR_MIGRATION_PLAN.md`
- 手工点击路径回归：`docs/IOS_MANUAL_NAVIGATION_CLICKPATH_CHECKLIST.md`
- 发布前冒烟执行：`docs/IOS_RELEASE_SMOKE_RUNBOOK.md`

建议执行顺序：

1. 先看本规范（怎么做）。
2. 再看迁移计划（现在做到哪）。
3. 实现后按点击路径清单回归（是否通）。

