# API 契约统一落地执行方案

> Status: In Progress  
> Owner: Server / Web / iOS  
> Last Updated: 2026-05-30  
> Primary Scope: `server/`, `web/`, `mobile/ios/RaverMVP/`, `docs/`

## 0. 可追溯进度

### Phase 0：方向确认

- [x] 确认问题根因不是单纯 HTTP `PATCH`，而是多端编辑提交语义和字段清空语义漂移
- [x] 确认 Event 主线当前已经切到 full payload contract，不再继续走 patch-only payload
- [x] 确认本项目统一契约首选 `OpenAPI 3.1`
- [x] 确认采用 spec-first 方案，而不是继续手写 iOS / Web 双份请求模型
- [x] 确认第一阶段只收口 `Event`，不同时改 Organizer / DJ
- [x] 确认第一阶段优先统一“契约 + 生成类型 + parity tests”，暂不强制替换全部请求客户端

### Phase 1：Event 契约源建立

- [x] 新建统一契约目录与命名规范
- [x] 新建 Event admin / upload 第一版 `OpenAPI 3.1` 文档
- [x] 抽出 `CreateEventInput`
- [x] 抽出 `UpdateEventInput`
- [x] 抽出 Event create / update 成功返回体
- [x] 抽出 submission accepted 返回体
- [x] 抽出统一错误返回体与错误码说明
- [x] 在契约中明确 full payload only 原则
- [x] 在契约中明确 `clear*` 字段语义
- [x] 在契约中明确 `schedule / weeks / eventDays / lineupArtists / lineupSlots / stageOrder` 结构
- [x] 修正 Swift OpenAPI 生成兼容性：对象型可空字段改为稳定可生成写法

### Phase 2：代码生成与接入

- [x] 为 Web 接入 OpenAPI 到 TS 类型生成
- [x] 为 iOS 接入 OpenAPI 到 Swift 模型生成
- [x] 在 workspace 级别完成 `RaverEventAdminContract` build 验证
- [x] 修正 `lineupSyncMode / status` 的 Swift 生成兼容写法，并重新生成最新 contract 产物
- [x] iOS `WebFeatureService / LiveWebFeatureService / MockWebFeatureService` 已并行接入 generated Event contract overload
- [x] iOS `EventUploadFlow` 的 mapper 与 submit 主链已切到 generated Event contract input
- [x] 为 iOS 旧手写 Event request model 与 service overload 标记 legacy 边界，禁止新流程继续依赖
- [x] Web Event Studio 改为消费生成后的 Event contract types
- [x] iOS EventUploadFlow 改为消费生成后的 Event contract models
- [x] 删除或冻结 Web 侧手写 Event API contract type
- [x] 删除或冻结 iOS 侧手写 Event API model

### Phase 3：映射规则与一致性校验

- [x] 把 Web `draft -> UpdateEventInput` 映射改为严格对齐统一契约
- [x] 把 iOS `draft -> UpdateEventInput` 映射改为严格对齐统一契约
- [x] 补齐 Web 侧缺失的 `clear*` 语义
- [x] 建立 Event payload fixtures
- [x] 新增 Web fixture contract compile-check：`pnpm run test:contracts:event`
- [x] 建立 Web payload parity tests
- [x] 建立 iOS payload parity tests
- [x] 建立 CI 校验：契约变更后生成产物必须同步更新
- [x] iOS `MockWebFeatureService` 已改为以 generated Event contract 作为 create / update / preview 主入口

### Phase 4：服务端归一化与验收

- [x] 服务端补充对契约 schema 的入站校验
- [x] 服务端补充对 full payload 必填语义的 guardrail
- [x] 服务端补充对 `clear*` 语义的回归测试
- [ ] Web / iOS / Server 三端完成 Event 编辑联调
- [ ] 将 Event 契约统一方案复制到 Organizer
- [ ] 将 Event 契约统一方案复制到 DJ

## 1. 目标

这项工作的目标不是“再维护一份更大的文档”，而是把 Web 和 iOS 当前分别手写、分别漂移的 Event 编辑契约，收口成一份唯一来源。

我们最终要达到：

- Web 与 iOS 共享同一份 Event API 契约
- 字段新增、删除、清空语义只改一处
- 两端不再各自维护一份手写 `UpdateEventInput`
- 契约变化能够通过生成、测试、CI 被强制发现
- 服务端继续作为最终业务语义兜底层

## 2. 现状判断

当前项目的问题不是“iOS 用全量覆盖，Web 还在传统 patch”。

真实现状是：

- iOS 网络方法仍然是 `PATCH /v1/events/:id`
- iOS 编辑提交语义已经转成 full payload only
- Web 也已经在走 full payload 风格的编辑提交
- 但 Web 的 `UpdateEventInput`、`clear*` 字段、draft mapper 还没有和 iOS 严格镜像

这会导致：

- 一边新增字段，另一边容易漏改
- 一边补清空语义，另一边容易残留旧值
- Web / iOS / Server 对“同一个字段是否允许缺省、是否代表清空”理解不一致

## 3. 为什么选 OpenAPI 3.1

本项目当前最适合的统一契约方式是 `OpenAPI 3.1`，原因如下：

- 现有主线是 REST + JSON + HTTP，不是 gRPC / GraphQL
- 我们不仅要描述字段，还要描述 path、method、request body、response、error body、auth
- `OpenAPI 3.1` 适合作为 HTTP API 的唯一机器可读契约
- `OpenAPI 3.1` 可以承载 JSON Schema 风格的数据结构定义
- Web 和 iOS 都有成熟的生成链可接

本项目当前不优先采用以下方案：

- 只用 `JSON Schema`
  - 只能很好描述 JSON 结构，不能完整描述 HTTP API 契约
- `Protobuf / gRPC`
  - 与当前架构不匹配，迁移成本过高
- `GraphQL SDL`
  - 当前后端主线不是 GraphQL
- 自定义 YAML / TS / Swift 描述格式
  - 长期维护成本最高，最容易再次分叉

## 4. 方案总览

统一契约方案采用四层结构：

1. 契约层  
   唯一事实来源，使用 `OpenAPI 3.1`

2. 生成层  
   从契约生成：
   - Web 的 TS types
   - iOS 的 Swift models

3. 映射层  
   各端保留自己的 UI draft，但都映射到同一个生成后的 contract model

4. 归一化层  
   服务端继续负责最终结构校验、默认值、清空语义、lineup / timetable 归一化

## 5. 目录与产物规划

建议新增以下结构：

```text
contracts/
  openapi/
    event-admin.v1.yaml
  generated/
    web/
    ios/
  fixtures/
    event/
      update-basic.json
      update-clear-location.json
      update-lineup-replace.json
      update-schedule-multi-week.json
```

建议职责如下：

- `contracts/openapi/event-admin.v1.yaml`
  - Event create / update / read / submission 相关统一契约
- `contracts/generated/web/`
  - 自动生成的 TS types
- `contracts/generated/ios/`
  - 自动生成的 Swift models
- `contracts/fixtures/event/*.json`
  - 用于 Web / iOS parity tests 的基准 payload

## 6. 工具建议

### 6.1 Web

建议使用：

- `openapi-typescript`

用途：

- 生成 TS 类型
- 先不强制切换整套 fetch client
- 优先降低手写 type 漂移

### 6.2 iOS

建议分两步：

- 第一阶段：生成 Swift models，保留现有 `LiveWebFeatureService`
- 第二阶段：再考虑是否逐步接入更自动化的 operation client

当前已完成第一阶段的本地验证，并已将 `RaverEventAdminContract` 接入 `RaverMVP.xcodeproj`。
workspace 级别 build 已验证通过，命令执行时需要 `-skipPackagePluginValidation`。

原因：

- 当前 iOS 工程有自己的 `WebFeatureService` / `LiveWebFeatureService` 组织方式
- 一次性替换整套网络层风险大
- 先统一模型和编码语义，性价比最高

## 7. 关键设计原则

### 7.1 full payload only

`UpdateEventInput` 继续保持 full payload only，不重新引入 patch-only payload。

### 7.2 clear 语义显式化

凡是“字段缺省”和“字段清空”含义不同的字段，都必须显式定义 `clear*`。

典型包括：

- `clearWikiFestivalId`
- `clearManualLocation`
- `clearLocationPoint`
- `clearLatitude`
- `clearLongitude`
- `clearStageOrder`
- `clearLineupSlots`
- `clearCityI18n`
- `clearCountryI18n`

后续如果发现其它字段也存在“缺省不等于清空”，也必须继续补齐，而不是靠客户端隐式约定。

### 7.3 UI state 不共享，contract model 共享

不要尝试让 SwiftUI 页面和 React 页面共用一套 UI 状态模型。

应该共享的是：

- 请求 contract
- 响应 contract
- 错误 contract
- fixtures
- parity tests

### 7.4 服务端是最终语义裁判

客户端统一 contract 之后，服务端仍然保留：

- 结构校验
- 语义归一化
- 兼容性 guardrail
- 提交幂等
- direct apply / submission route 判定

## 8. Event 第一阶段的具体落地内容

第一阶段只处理 Event，并明确覆盖以下对象：

- `CreateEventInput`
- `UpdateEventInput`
- Event 成功返回体
- submission accepted 返回体
- 标准错误体
- Event lineup / timetable alignment preview 的输入输出

第一阶段不做的事：

- 不同时统一 Organizer / DJ
- 不强制替换所有旧页面调用
- 不把整个服务端自动生成路由文档一次性补齐
- 不要求 festival-viewer 立刻全量接入

## 9. 测试与 CI 策略

这部分是整个方案能不能长期稳定的关键。

### 9.1 Fixtures

至少建立以下 Event fixtures：

- `update-basic.json`
- `update-clear-location.json`
- `update-clear-i18n.json`
- `update-lineup-replace.json`
- `update-schedule-multi-week.json`

### 9.2 Web parity tests

验证：

- 输入相同 draft 时，Web mapper 生成的 JSON 与 fixture 一致
- 当前已落地可执行入口：`pnpm run test:parity:event`
- 当前已覆盖：`eventDayId / weekIndex / dayIndexInWeek / overallDayIndex / formattedAddressI18n / ticketTiers.sortOrder / lineupSlots.festivalDayIndex / 跨午夜 endTime / clear*`

### 9.3 iOS parity tests

验证：

- 输入相同 draft 时，iOS mapper 编码后的 JSON 与 fixture 一致
- 当前已新增 `RaverMVPTests` unit test target，作为 Event contract parity 的正式承载层
- 当前已落地 `EventContractParityTests.swift` 与 `EventUploadMultiWeekModelTests.swift` 的 generated contract 断言改造
- 当前已补入 `EventLineupDraftDerivationTests.swift` 到 `RaverMVPTests` target，覆盖旧编辑页从 timetable 推导 lineup artists 的回归语义
- 当前已将 `EventUploadMappers` 改为直接产出 generated Event contract mutation payload，不再在 update / image-only update 路径中中转 legacy `UpdateEventInput`
- 当前已修正创建后图片补传语义：`imageOnlyUpdateInput` 现在也会携带完整 Event payload，继续满足 full-payload-only 契约
- 当前已将 `MockWebFeatureService` 的 generated Event create / update / preview 路径改成原生实现，legacy overload 只保留兼容桥接
- 当前已完成 workspace 级 `build-for-testing` + `test-without-building` 收口
- 当前已验证通过：`EventContractParityTests` + `EventUploadMultiWeekModelTests`，共 `5` 个测试全部通过
- 当前已验证通过：`RaverMVP.xcworkspace` focused tests（`EventContractParityTests` + `EventUploadMultiWeekModelTests` + `EventLineupDraftDerivationTests`），共 `7` 个测试全部通过
- 当前已验证通过：`RaverMVP.xcworkspace` focused tests（新增 image-only full payload 回归后），共 `8` 个测试全部通过
- 当前已验证通过：`RaverMVP.xcworkspace` focused tests（新增 Mock generated-path 回归后），共 `10` 个测试全部通过
- 当前已覆盖：`status` 推导、默认 `stageName` 规范值、`eventDayId / weekIndex / dayIndexInWeek / overallDayIndex / localDate / lineupSlots.festivalDayIndex / 跨午夜 endTime / clear*`

### 9.4 CI gate

新增以下门禁：

- 契约文件变更后，生成产物若未同步更新则失败
- Web parity tests 失败则失败
- iOS parity tests 失败则失败
- 旧 Web `lib/api/event.ts` 与 iOS `CreateEventInput / UpdateEventInput` 继续被新代码使用时，应通过 deprecated 警告被立即暴露
- 当前已新增：`.github/workflows/event-contract-guard.yml`
- 当前已落地脚本：`scripts/check-event-admin-contract-sync.sh`、`scripts/run-ios-event-contract-parity.sh`
- 当前已补齐：iOS parity 脚本与 `event-contract-guard` workflow 已纳入 `EventLineupDraftDerivationTests`，并覆盖 `EventEditorView.swift` / `EventLineupSupport.swift` / `RaverMVP.xcodeproj` 的触发路径
- 当前已完成本地校验：Web contract compile-check、contract sync check、workflow YAML 解析、iOS parity 脚本全链路通过
- 当前本地闭环结果：`scripts/run-ios-event-contract-parity.sh` 已通过，说明 workflow 里的 iOS Event contract gate 命令链可直接复用
- 当前已新增：`server/src/scripts/event-admin-contract-guardrails.ts`
- 当前已验证通过：`pnpm --dir server exec ts-node src/scripts/event-admin-contract-guardrails.ts`
- 当前已验证通过：`pnpm --dir server exec tsc --noEmit`

## 10. 执行顺序

建议严格按以下顺序推进：

1. 建立 Event OpenAPI 契约源
2. 把当前 iOS / Web 的 `UpdateEventInput` 差异对齐进契约
3. 接上 Web 类型生成
4. 接上 iOS 模型生成
5. 改 Web Event mapper
6. 改 iOS Event mapper
7. 建 fixtures
8. 建 parity tests
9. 最后再考虑扩展到 Organizer / DJ

## 11. 当前已知改造点

基于当前仓库，Event 线至少需要处理这些现实问题：

- 旧 `EventEditorView` 主提交流已切到 generated Event contract，但仍需要继续完成 workspace 级验证并逐步清退 legacy overload
- 旧 Web `lib/api/event.ts` 仍保留非契约化的 `Partial<Event>` 事件写接口，但现在已经被 deprecated 冻结
- draft mapper 规则分散在两端，缺少统一基准 fixture
- 契约变化没有生成门禁和 parity tests

## 12. 验收标准

达到以下条件，才算第一阶段完成：

- Web 与 iOS 的 Event request model 来自同一份契约源
- Web 与 iOS 不再手写两份独立 `UpdateEventInput`
- `clear*` 字段语义在契约、Web、iOS、服务端四处一致
- 同一组 fixture 在 Web 与 iOS 上都能生成一致 payload
- CI 能阻止“只改一端、不改另一端”的漂移进入主干

## 13. 风险与控制

### 风险 1：一次性切太大

控制：

- 只先做 Event
- 只先收 contract 与 generated types
- 现有服务层先不大重写

### 风险 2：生成产物进入仓库后噪音大

控制：

- 只提交必要生成物
- 命名和目录严格固定
- 由 CI 校验生成结果是否一致

### 风险 3：服务端现有隐式语义没有被契约显式化

控制：

- 先补 schema 注释和错误码说明
- 逐步把隐式规则转成 contract + tests

## 14. 与现有文档关系

这份文档是“统一契约执行主文档”。

相关背景以现有文档为准：

- `docs/WEB_UNIFIED_ADMIN_ALIGNMENT_MASTER_PLAN.md`
- `docs/EVENT_EDIT_TIMETABLE_REARCHITECTURE_PLAN.md`

后续涉及 Event 契约统一的推进，以本文件 checkbox 为主更新入口。

## 15. 下一步

下一步优先做两件事：

- 观察 `event-contract-guard` 首次 CI 运行结果，并根据 runner 上的 SwiftPM / simulator 环境做一次收口
- 开始替换旧 `EventEditorView` 路径上的手写 Event input，逐步移除 deprecated legacy overload，避免长期保留双轨

## 16. EventEditorView 收口进度

- [x] 为 iOS `EventCommandRepository` 补齐 generated Event contract overload
- [x] 旧 `EventEditorView` `save()` 主链改为通过 `EventUploadDraft + EventUploadMappers` 产出 generated Event contract payload
- [x] 旧 `EventEditorView` 创建后图片补传改为复用 `imageOnlyUpdateInput`
- [x] `imageOnlyUpdateInput` 已改为输出 full Event payload，避免创建后图片补传退回半截 update 语义
- [x] 旧 `EventEditorView` 编辑提交不再直接手写 `UpdateEventInput`
- [x] 旧 `EventEditorView` 时区预填充在提交前归一到 `event-edit-hydrate` 语义，避免无意义回写城市时区元数据
- [x] 新增 `EventLineupDraftDerivationTests.swift` 并接入 `RaverMVPTests` target
- [x] 完成 `RaverMVP.xcworkspace` focused test 验证（`7` tests passed）
- [x] `EventUploadMappers` 的 update / image-only update 路径已去除 legacy `UpdateEventInput` 中转
- [x] `MockWebFeatureService` 的 generated Event create / update / preview 路径已改为原生实现，legacy overload 仅保留兼容壳
- [x] 完成 `RaverMVP.xcworkspace` focused test 再验证（`10` tests passed）

## 17. Phase 4 启动门槛

- [x] iOS Event 主编辑流已不再实际依赖 legacy `CreateEventInput / UpdateEventInput`
- [x] iOS `LiveWebFeatureService` 与 `MockWebFeatureService` 都已把 generated Event contract 作为主入口
- [x] iOS focused parity tests 与 CI gate 已覆盖当前 Event 契约主链
- [x] 服务端 Event schema 入站校验任务已确认并开始改造
- [x] 服务端 full payload / `clear*` guardrail 已补齐
- [ ] Web / iOS / Server 三端联调窗口已确认并执行

## 18. Phase 4 服务端落点

- [x] `server/src/routes/event.routes.ts` 新增 `PATCH /:id`，对齐统一 Event admin contract
- [x] `server/src/controllers/event.controller.ts` 在 create / update 入口接入 Event admin contract guardrail
- [x] `server/src/services/event-admin-contract-guardrail.service.ts` 已落地 full payload / `clear*` 语义校验
- [x] `server/src/scripts/event-admin-contract-guardrails.ts` 已覆盖缺失 schedule、缺失 clear flag、partial omission、clear 冲突回归场景
- [x] `web/src/lib/api/event.ts` 的 deprecated 旧更新入口已切到 `PATCH`，与统一 contract 动词保持一致
- [ ] 下一步执行一次 Web / iOS / Server 三端真实请求联调
