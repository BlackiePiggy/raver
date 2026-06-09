# iOS 答题系统主线改造方案

> Status: Draft
> Owner: Backend / Web Admin / iOS
> Last Updated: 2026-06-09
> Scope: `server/`, `web/`, `mobile/ios/`, `server/prisma/`, `docs/`

---

## 目标

建设一套围绕 `iOS 用户答题` 的完整主线能力：

- iOS 端在个人主页快捷入口新增答题入口
- 用户每次答题从题库中随机抽取 `20` 道单选题
- 题干与选项都支持图片
- 答题过程中不展示正确答案，不展示逐题反馈
- 最终结果页只展示：
  - 答对数量
  - 是否通过
- 按“答对题数达到 N”判定是否通过
- 每题限制答题时间，超时自动判错并直接进入下一题
- 若题目包含媒体资源，则必须在进入该题页面前完成预加载后才开始计时
- 题库由 web 端后台维护
- 该能力将来会影响权限 / 认证，因此要从一开始预留合格状态接入点

---

## 战略执行原则

### 1. 始终紧跟主线，不发散

- [x] 本次改造只围绕 `题库后台 + 答题会话 + iOS 答题流 + 合格状态` 主线推进
- [x] 不顺手扩散到排行榜、社交分享、勋章系统、学习记录页等衍生功能
- [x] 发现非主线问题时，只记录，不插队处理
- [x] 每完成一段主线工作，都必须回到本文档勾选进度

### 2. 不做旧方案兼容负担

- [x] 当前项目阶段允许直接采用终局主线设计
- [x] 不做长期双写 / 双读 / 长期 fallback
- [x] 若为了平滑开发出现临时兼容代码，主线完成后应清理

### 3. 以服务端为准控制抽题与判题

- [x] 抽题在服务端完成
- [x] 正确答案不下发给 iOS 客户端
- [x] 判题在服务端完成
- [x] iOS 仅持有当前答题所需展示数据和用户作答状态

---

## 需求冻结

以下需求已冻结为当前版本执行依据：

- [x] 题型当前全部为单选题
- [x] 题干支持图片
- [x] 选项支持图片
- [x] 当前只做中文
- [x] 当前抽题规则为全局随机抽取
- [x] 未来会预留标签 / 难度 / 题型等扩展口
- [x] 每次答题固定抽取 `20` 题
- [x] 通过规则为“答对数量达到 N”
- [x] `N` 可由 web 后台调整
- [x] 每日可答题次数默认 `3` 次
- [x] 每日次数可由 web 后台调整
- [x] 特定用户可由 web 后台设置专属每日次数
- [x] 特定用户可由 web 后台设置为无限次，便于官方测试与权限验证
- [x] 通过结果永久有效
- [x] 用户端不展示答题记录
- [x] 用户允许主动重新开始整场答题
- [x] 单题超时后自动判错并直接跳下一题
- [x] 单题媒体资源加载失败时最多重试 `3` 次，仍失败则该题跳过并判错
- [x] 整场题目与展示 payload 一次性获取
- [x] 不允许返回上一题
- [x] 不允许退出后继续
- [x] 允许截图
- [x] 限制复制和长按
- [x] 结果页只展示答对数量和通过结果
- [x] 所有用户都可以参加
- [x] 合格结果未来会影响权限 / 认证，当前要预留接入口

---

## 关键设计结论

## 1. “不保留答题记录”的真实含义

你要求“不要保留答题记录，用户看不到答题记录”，但同时又要求：

- 每日 `3` 次限制
- 通过后永久有效
- 未来影响权限 / 认证

因此系统必须保留**最小必要服务端状态**，但不做用户可见历史，不保留逐题答案历史。

### 最小必要保留

- [x] 用户当天已使用次数
- [x] 用户是否已通过
- [x] 首次通过时间
- [x] 最近一次答题的汇总结果
- [x] 当前正在进行中的答题 session 状态

### 明确不保留或不对用户开放

- [x] 不对用户展示历史答题列表
- [x] 不对用户展示逐题作答详情
- [x] 不对用户展示历史成绩变化曲线
- [x] 不长期保存逐题答案明细作为业务主数据

---

## 2. V1 题目模型

当前只做单选题，但要给未来扩展留口。

### Question

- [x] `id`
- [x] `status`
  - `draft | active | archived`
- [x] `type`
  - 当前只允许 `single_choice`
- [x] `stemText`
- [x] `stemImageUrl`
- [x] `options`
- [x] `correctOptionId`
- [x] `timeLimitSec`
- [x] `sortOrder`
- [x] `tags`
  - 当前先留口，不参与抽题
- [x] `difficulty`
  - 当前先留口，不参与抽题
- [x] `explanation`
  - 当前后台可不开放，或留空；前台答题不展示
- [x] `createdAt / updatedAt`

### Option

- [x] `id`
- [x] `text`
- [x] `imageUrl`
- [x] `sortOrder`

### V1 约束

- [x] 每题至少 `2` 个选项
- [x] 每题最多 `6` 个选项
- [x] 每题只能有 `1` 个正确答案
- [x] 选项允许“仅图片”“仅文字”或“图文同时存在”
- [x] 题干允许“仅图片”“仅文字”或“图文同时存在”

---

## 3. V1 考试配置模型

需要有一份独立的全局配置，而不是把规则写死在客户端。

### QuizConfig

- [x] `id`
- [x] `isEnabled`
- [x] `questionCount`
  - V1 默认 `20`
- [x] `passCorrectCount`
  - 例如 `16`
- [x] `dailyAttemptLimit`
  - 默认 `3`
- [x] `defaultTimeLimitSec`
  - 用于题目未单独配置时兜底
- [x] `dailyLimitTimeZone`
  - 默认 `Asia/Shanghai`
- [x] `allowRetakeAfterPass`
  - V1 建议为 `true`
- [x] `allowRestartDuringSession`
  - V1 为 `true`
- [x] `updatedAt`

### 当前决策

- [x] 日限额按“业务时区自然日”计算
- [x] V1 默认业务时区为 `Asia/Shanghai`
- [x] 用户级次数策略优先级高于全局默认配置
- [x] 用户级策略支持：
  - [x] 沿用全局默认
  - [x] 指定专属每日次数
  - [x] 无限次
- [x] 通过后永久有效
- [x] 通过后是否还能继续答题先保留为后台可配
- [x] V1 默认允许通过后继续重新答题，但不影响已获得的通过资格

---

## 4. 会话与判题模型

因为不允许退出后继续，session 模型要清晰而轻量。

### QuizSession

- [x] `id`
- [x] `userId`
- [x] `status`
  - `in_progress | submitted | expired | abandoned`
- [x] `configSnapshot`
- [x] `questionSnapshot`
  - 仅保留本次会话用到的题目快照
- [x] `currentQuestionIndex`
- [x] `startedAt`
- [x] `expiresAt`
- [x] `submittedAt`
- [x] `correctCount`
- [x] `passed`

### QuizSessionQuestionSnapshot

- [x] `questionId`
- [x] `stemText`
- [x] `stemImageUrl`
- [x] `options`
- [x] `correctOptionId`
  - 仅服务端内部保存，不返回客户端
- [x] `timeLimitSec`

### QuizAttemptLedger

用于每日限次与永久通过状态。

- [x] `userId`
- [x] `attemptDateKey`
  - 例如 `2026-06-08@Asia/Shanghai`
- [x] `attemptCount`
- [x] `passed`
- [x] `passedAt`
- [x] `lastSessionId`

### QuizUserPolicyOverride

用于后台对特定用户设置 quiz 策略覆盖，优先级高于全局 `QuizConfig`。

- [x] `userId`
- [x] `attemptMode`
  - `default | custom_limit | unlimited`
- [x] `dailyAttemptLimitOverride`
- [x] `note`
- [x] `updatedBy`
- [x] `updatedAt`

---

## 5. iOS 端答题体验主线

### 入口

- [x] 入口先放到个人主页快捷入口
- [x] 当前预期挂点为：
  - [x] [ProfileView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift)
  - [x] `profileQuickActions`

### 页面流

1. 进入答题入口
2. 查看开始页
3. 点击开始后向服务端创建 session
4. 一次性拿到本次 20 题的展示 payload
5. 客户端预加载第 1 题资源
6. 资源就绪后进入第 1 题并开始倒计时
7. 作答 / 超时 / 跳题后进入下一题
8. 全部完成后提交
9. 结果页只显示：
   - 答对 `X/20`
   - 是否通过

### 单题行为

- [x] 单选后允许立即下一题
- [x] 也可以在时间结束前修改本题选择，最终以倒计时结束或点击下一题时的最后选择为准
- [x] 若超时未选，则自动判错并进入下一题
- [x] 不允许返回上一题
- [x] 不允许查看正确答案
- [x] 不允许查看解释

### 重启行为

- [x] 用户可主动“重新开始整场答题”
- [x] 重新开始会放弃当前 session
- [x] 是否计入当天次数由服务端统一控制

### 主动放弃行为

- [x] 用户确认放弃后，iOS 本地界面立即退出答题页并返回开始页
- [x] 放弃 session 的服务端收尾异步完成，不阻塞本地退场反馈
- [x] 重新开始仍保持“先关闭旧 session，再创建新 session”的顺序，避免服务端判定仍有进行中答题

### 建议的次数策略

- [x] 创建 session 即占用 1 次当日机会
- [x] 重启整场会再次创建新 session，因此再次占用 1 次
- [x] 这样可以避免通过反复 restart 无限刷题而不消耗次数

---

## 6. 媒体预加载策略

这是本次能力的关键约束之一。

### 原则

- [x] 某题只有在本题所需媒体全部准备好后，才允许进入题目页面并开始计时
- [x] 计时开始点以后，不能因为图片慢加载而损耗用户作答时间

### V1 方案

- [x] 服务端一次性返回 20 题的结构化 payload
- [x] iOS 客户端在答题开始后，优先预加载当前题资源
- [x] 同时后台低优先级预取后续若干题资源
- [x] 当前题资源包括：
  - [x] 题干图片
  - [x] 各选项图片

### 失败处理

- [x] 单题媒体拉取失败时最多自动重试 `3` 次
- [x] 仍失败则该题直接记错并跳到下一题
- [x] 该失败过程不进入倒计时
- [x] 结果页不额外暴露失败原因

### 性能原则

- [x] 不要求开始前把 20 题全部图片完全下载完再进入答题
- [x] 只要求“进入某题前，这一题自己的资源已经可用”
- [x] 避免首屏等待过长

---

## 7. 安全与反作弊边界

V1 不追求强对抗，但要有清晰边界。

### 当前冻结规则

- [x] 不允许返回上一题
- [x] 不允许退出后继续
- [x] 允许截图
- [x] 限制复制和长按

### 建议补充规则

- [x] App 切后台时，当前 session 直接标记 `abandoned`
- [x] 用户重新进入时不可恢复之前 session
- [x] 如果后续想放宽，也应先由服务端 session 状态控制，而不是只在客户端做容错

### 正确答案保护

- [x] 正确答案不返回客户端
- [x] 客户端只拿展示用题目快照
- [x] 判题提交时仅上传用户选择结果

---

## 8. 权限 / 认证预留口

虽然 V1 先不真正改权限系统，但必须预留清晰接入口。

### 需要预留的能力

- [x] 读取用户是否已通过 quiz
- [x] 读取用户通过时间
- [x] 在权限判断中可挂接：
  - [x] 是否允许进行某动作
  - [x] 是否满足某认证前置条件

### 建议抽象

- [x] 不把 quiz 通过状态散落在多个业务表里
- [x] 建议抽象为统一的 `user qualification / certification` 结构
- [x] 当前 quiz 只是其中一种 qualification
- [x] 以后可扩展其他认证来源，而不重做整套判断链路

---

## 9. Web 后台能力范围

当前 web 端要做两类后台：

### A. 题库管理

- [x] 题目列表页
- [x] 新建题目
- [x] 编辑题目
- [x] 启用 / 停用题目
- [x] 删除或归档题目
- [x] 图片上传
- [x] 题目预览

### B. 答题系统配置

- [x] 是否启用答题系统
- [x] 抽题数量
- [x] 通过所需正确题数
- [x] 每日答题次数
- [x] 默认单题时长
- [x] 业务日界线时区
- [x] 通过后是否允许继续答题
- [x] 用户级次数覆盖管理
- [x] 用户级无限次管理

### 未来预留但 V1 不启用

- [x] 标签
- [x] 难度
- [x] 按分类配比抽题
- [x] 多套题库 / 多个考试

---

## 10. API 主线设计

### 用户端 API

- [x] `GET /v1/quiz/config`
  - 返回当前是否启用、用户是否有资格进入、基础规则摘要
- [x] `GET /v1/quiz/status`
  - 返回：
    - 今日剩余次数
    - 是否已通过
    - 通过时间
- [x] `POST /v1/quiz/sessions`
  - 创建答题 session
  - 一次性返回本次 20 题的展示 payload
- [x] `POST /v1/quiz/sessions/:id/answer`
  - V1 不实现，明确保留为后续增强口；当前主线采用“本地暂存 + 最终汇总提交”
- [x] `POST /v1/quiz/sessions/:id/submit`
  - 提交整场结果
- [x] `POST /v1/quiz/sessions/:id/abandon`
  - 主动放弃 / 重启前关闭旧 session

### 管理端 API

- [x] `GET /admin/v1/quiz/questions`
- [x] `POST /admin/v1/quiz/questions`
- [x] `GET /admin/v1/quiz/questions/:id`
- [x] `PATCH /admin/v1/quiz/questions/:id`
- [x] `POST /admin/v1/quiz/questions/:id/archive`
- [x] `GET /admin/v1/quiz/config`
- [x] `PATCH /admin/v1/quiz/config`
- [x] `GET /admin/v1/quiz/user-overrides`
- [x] `PATCH /admin/v1/quiz/users/:userId/override`

### 关于逐题提交的选择

V1 推荐：

- [x] 以本地暂存 + 最终汇总提交为主
- [x] 服务端只在 session 创建和 session 提交时处理主流程
- [x] 若后续需要更强的防作弊或掉线容错，再演进到逐题提交

---

## 11. 数据库改造建议

### 建议新增表

- [x] `QuizQuestion`
- [x] `QuizQuestionOption`
- [x] `QuizConfig`
- [x] `QuizSession`
- [x] `QuizAttemptLedger`
- [x] `QuizUserPolicyOverride`
- [x] 可选：`UserQualification`
  - V1 不单独建表，先由统一 `accountQualificationService` 聚合 quiz qualification，满足权限接入口主线

### 媒体字段策略

- [x] 直接复用现有媒体 URL 模式
- [x] 不单独造 quiz 专属文件存储体系
- [x] web 后台沿用现有上传机制即可

---

## 12. 关键产品决策说明

### 为什么“重启”仍应消耗次数

- [x] 否则用户可以不断 restart，直到刷到熟悉题或更容易的组合
- [x] 这会直接削弱每日 3 次限制
- [x] 因此推荐“创建 session 即消耗一次机会”

### 为什么仍要保留最小服务端状态

- [x] 没有状态就无法：
  - [x] 限制每日 3 次
  - [x] 记录永久通过
  - [x] 影响权限 / 认证
- [x] 但可以不保存逐题答案历史，从而满足“用户看不到答题记录”的业务目标

### 为什么不在开始前预下载全部 20 题图片

- [x] 可能导致首屏等待过长
- [x] 当前只要求“进入当前题前已准备好本题资源”即可
- [x] 更适合移动端体验

---

## 13. 当前代码挂点确认

### iOS 个人主页快捷入口

- [x] [ProfileView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift)
  - [x] `profileQuickActions`

### Web 管理侧导航

- [x] [navigation.ts](/Users/blackie/Projects/raver/web/src/lib/admin/navigation.ts)
  - [x] 后续新增题库后台入口时要接这里

### 当前项目现状

- [x] 目前项目中没有现成 quiz / question-bank 模块
- [x] 因此本次属于完整新模块建设，而不是在旧答题系统上改造

---

## 执行分期

## Phase 0. 文档冻结

- [x] 冻结本方案文档
- [x] 冻结 V1 规则
- [x] 写入“紧跟主线、每次回写 md 进度”要求

## Phase 1. Server 数据模型与 DB

- [x] 新增 Prisma 数据模型
- [x] 生成 migration
- [x] 建立最小服务端状态结构
- [x] 确认不保存长期逐题答案明细

## Phase 2. Server 用户端答题链路

- [x] 实现 quiz config / status / create session / submit session
- [x] 实现全局随机抽 20 题
- [x] 实现按正确数量判定通过
- [x] 实现每日次数限制
- [x] 实现永久通过状态写入

## Phase 3. Server 管理端链路

- [x] 实现题目 CRUD
- [x] 实现配置读写
- [x] 实现题目启停
- [x] 实现图片字段保存
- [x] 实现特定用户次数覆盖 / 无限次配置

## Phase 4. Web 后台 UI

- [x] 增加后台导航入口
- [x] 完成题库列表页
- [x] 完成题目编辑页
- [x] 完成答题配置页
- [x] 完成图片上传与预览
- [x] 完成用户级次数覆盖 / 无限次配置 UI

## Phase 5. iOS 答题入口与页面流

- [x] 在个人主页快捷入口增加答题入口
- [x] 新建答题开始页
- [x] 新建答题单题页
- [x] 新建答题结果页
- [x] 新建答题中断 / 放弃 / 重启交互

## Phase 6. iOS 媒体预加载与计时

- [x] 进入题目前完成该题媒体预加载
- [x] 媒体失败 3 次后跳题判错
- [x] 单题倒计时完成自动判错并下一题
- [x] 不允许返回上一题
- [x] 不允许退出后继续

## Phase 7. 权限接入口预留

- [x] 增加统一 qualification 读取口
- [x] 让 quiz pass 状态可被权限链路消费
- [x] 暂不改具体业务权限，只把接口留好

## Phase 8. QA 与回归

- [x] 服务端抽题 / 判题 / 限次测试
- [x] web 题库管理测试
- [x] iOS 单题倒计时测试
- [x] iOS 图片预加载测试
- [x] iOS 重启 / 放弃 / 切后台测试
- [x] 权限接入口冒烟测试

---

## 风险清单

- [x] 若完全不保存最小服务端状态，则无法满足业务规则
- [x] 若重启不消耗次数，会被用来绕过每日上限
- [ ] 若把图片全部提前下载完再开题，弱网下首屏会过慢
- [x] 若正确答案进入客户端，会天然削弱题目安全性
- [ ] 若未来权限直接耦合到单一 quiz 表，会影响后续认证体系扩展

---

## 本轮已完成

- [x] 需求冻结
- [x] 主线执行原则写入文档
- [x] 现有 iOS 快捷入口挂点确认
- [x] 现有 web admin 导航挂点确认
- [x] 生成本执行文档作为后续唯一主线依据
- [x] iOS Phase 5 页面流主线完成
- [x] iOS Phase 6 预加载与计时主线完成
- [x] Phase 7 统一 qualification 读取口已落地到 server / iOS
- [x] 服务端新增 `quiz:qualification:smoke` 主线 smoke 脚本
- [x] 服务端新增 `quiz:admin:smoke`，已覆盖 quiz config / 题目 CRUD / 用户次数覆盖主链路
- [x] Quiz schema / migration 已落库并修复 failed migration，Phase 8 服务端 smoke 已跑通
- [x] Smoke 已验证 qualification 状态可随答题通过结果从 `unqualified` 切换到 `qualified`
- [x] `QuizFlowViewModelTests` 已覆盖 iOS 倒计时超时自动提交、媒体预加载后起题、切后台放弃会话三条主线回归
- [x] Web quiz admin 已补齐题目预览，题库管理 / 全局配置 / 用户次数覆盖主线与文档状态对齐
- [x] 已明确 V1 不实现逐题提交接口，主线固定为 session create + session submit
- [x] 已明确 V1 不新增独立 `UserQualification` 表，由统一 qualification service 先承接权限读取
- [x] `quiz:qualification:smoke` 已补充验证：session payload 不下发正确答案，abandon / restart 不回退每日次数
- [x] iOS 主动放弃答题已改为“本地立即退出 + 后端异步 abandon”，修复确认放弃后仍停留在答题页的问题
- [x] Quiz 题干 / 选项图片上传已收敛为 OSS 正式链路，不再回退本地上传，并切换到独立 `OSS_QUIZ_PREFIX`
- [x] Quiz 题目更新 / 删除时，已补齐未再被任何 quiz 题目引用的旧图资源回收逻辑
- [x] Web quiz 后台题干图 / 选项图输入区已改为“缩略图 + 灰色只读 URL + 全屏查看”，不再直接暴露可编辑 URL 输入框
- [x] Web quiz 题干图 / 选项图在上传 OSS 前已增加前端压缩，按 `stem` / `option` 不同尺寸上限缩放后再上传
- [x] Web quiz 图片上传后会在对应字段内显示压缩前后体积对比，并在切换题目 / 新建题目时清空历史上传对比
