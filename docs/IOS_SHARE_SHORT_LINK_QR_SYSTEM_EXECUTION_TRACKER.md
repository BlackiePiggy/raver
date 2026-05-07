# iOS 分享短链与二维码系统执行清单

关联主方案：`docs/IOS_SHARE_SHORT_LINK_QR_SYSTEM_PLAN.md`
关联日志：`docs/IOS_SHARE_SHORT_LINK_QR_SYSTEM_DEV_LOG.md`

## 1. 执行原则

### 1.1 主线范围

本执行清单只围绕以下 Phase 1 核心能力推进：

- iOS 统一分享入口
- HTTPS 短链与 Universal Link 主链路
- 个人名片 / 群名片永久分享链接
- 私密群临时邀请链接
- 二维码与分享海报基础资产
- 最小承接页
- 基础事件埋点
- 邀请关系绑定与奖励状态流转

### 1.2 明确不外扩

开发过程中不要主动扩展以下边界，除非主线能力全部收尾且你明确批准：

- Android 端接入
- 完整 Web 产品化页面
- DJ / Set / Label / Festival / Ranking / Rating / Circle ID 全量迁移
- 复杂广告归因平台接入
- 多语言 / 出海适配
- 复杂活动运营后台
- 高级海报编辑器

### 1.3 收尾优先级

遵循以下顺序，保证阶段性可收尾：

1. 先打通最小可用主链路
2. 再补对象接入
3. 再补邀请奖励
4. 再补风控和质量
5. 最后做扩展和体验增强

任何阶段都要求：

- 已开始的核心能力优先收尾，不开新的平行大坑
- 每完成一个大步骤，必须更新本清单和开发日志
- 关键设计变更只记到开发日志，不把主方案文档写成流水账

## 2. 总体进度

- [ ] Phase 0 完成：范围冻结与开发骨架就绪
- [ ] Phase 1 完成：短链主链路闭环
- [ ] Phase 2 完成：个人名片 / 群名片 / 邀请闭环
- [ ] Phase 3 完成：埋点与奖励状态闭环
- [ ] Phase 4 完成：风控与质量收尾
- [ ] MVP 收尾完成：可验收、可回归、可继续扩展

## 3. Phase 0：范围冻结与开发骨架

### 3.1 文档与边界冻结

- [x] 主方案文档完成第一版收敛
- [x] 执行清单建立
- [x] 开发日志文档建立
- [x] 在主方案文档中补充本执行清单和日志入口引用
- [x] 明确第一批接入对象白名单：`user_card`、`squad_card`、`post`、`event`、`news`、`squad_invite`
- [x] 明确第一批不接入对象黑名单，避免开发中途扩边界

### 3.2 技术骨架确认

- [x] 明确后端承载模块：Prisma / BFF / redirect handler / minimal landing
- [x] 明确 iOS 承载模块：`ShareLinkService` / `ShareCoordinator` / `UniversalLinkRouter` / `ShareActionPanel`
- [ ] 明确奖励规则承载位置：独立 service 或 BFF 内聚模块
- [x] 明确事件模型最小口径，防止一开始过度设计

### 3.3 本阶段收尾标准

- [x] 后续开发的主线对象、模块边界、阶段顺序已经固定
- [x] 执行清单可作为唯一开发推进面板使用

## 4. Phase 1：短链主链路闭环

目标：先打通“iOS 发起分享 -> 生成短链 -> 外部打开 -> 回到 App / 承接页”的最小链路。

### 4.1 后端数据层

- [x] 新增 `share_links` 表
- [x] 新增 `share_link_events` 表
- [x] 增加必要索引、唯一约束、状态字段
- [x] 生成并审查 migration
- [ ] 补充最小 seed / mock 数据策略

### 4.2 后端 API 层

- [x] `POST /api/bff/share-links/resolve`
- [x] `GET /api/bff/share-links/:code`
- [x] `POST /api/bff/share-links/:code/events`
- [x] `GET /s/:code`
- [x] `GET /qr/:code.png`
- [ ] `GET /poster/:code.png`
- [x] 统一错误返回：`revoked` / `expired` / `not_found`

### 4.3 最小承接页

- [ ] 支持 OG Meta 输出
- [ ] 支持“打开 Raver”按钮
- [ ] 支持“下载 App”按钮
- [ ] 支持失效状态页
- [ ] 支持私密邀请最小信息展示

### 4.4 iOS 核心服务层

- [x] 新增 `ShareTargetType`
- [x] 新增 `ShareTarget`
- [x] 新增 `ShareLinkPayload`
- [x] 新增 `ShareLinkService`
- [x] 新增 `ShareCoordinator`
- [ ] 新增 `UniversalLinkRouter`
- [ ] 增加 `applinks:raver.app` 配置

### 4.5 iOS UI 接入层

- [ ] `ShareActionPanel` 支持统一动作矩阵
- [x] Post 卡片接入统一复制链接
- [x] Post 详情接入统一复制链接
- [x] Event 详情接入统一复制链接
- [x] News 详情接入统一复制链接
- [x] 分享失败兜底策略完成

### 4.6 本阶段收尾标准

- [ ] iOS 已接入对象复制结果全部为 `https://raver.app/s/{code}`
- [ ] 已安装 App 时链接可拉起目标页
- [ ] 未安装时可进入最小承接页
- [ ] 主链路不依赖 Android / 完整 Web / 第三方归因平台

## 5. Phase 2：个人名片、群名片、邀请闭环

目标：在主链路稳定后，完成社交分享的两个核心资产和一个增长资产。

### 5.1 个人名片

- [x] 用户永久分享 code 生成策略落地
- [x] 用户二维码资产生成策略落地
- [x] 个人主页分享入口接入
- [x] 个人二维码页接入
- [ ] 个人海报页或保存海报能力接入

### 5.2 群名片

- [x] 群永久分享 code 生成策略落地
- [x] 群二维码资产生成策略落地
- [x] 群主页分享入口接入
- [x] 群二维码页接入
- [x] 旧 `qrCodeUrl` 兼容迁移方案落地

### 5.3 私密群邀请

- [x] 新增 `squad_invite` 链接能力
- [x] 支持邀请码过期时间
- [x] 支持邀请码最大使用次数
- [x] 支持邀请码重置
- [x] 支持邀请入口 UI
- [x] 支持邀请落地后的权限校验

### 5.4 本阶段收尾标准

- [ ] 个人名片、群名片、私密群邀请都能独立分享
- [ ] 永久码与临时码边界清晰
- [ ] 已开始的对象能力全部收尾，不新增新对象接入

## 6. Phase 3：埋点与奖励状态闭环

目标：把增长闭环做成可记录、可核对、可继续演进的最小商用版本。

### 6.1 事件埋点

- [ ] 记录 `create`
- [ ] 记录 `copy`
- [ ] 记录 `open`
- [ ] 记录 `redirect`
- [ ] 记录 `app_open`
- [x] 记录 `invite_accept`
- [x] 记录 `reward_grant`

### 6.2 邀请关系

- [x] 新增 `invite_referrals` 表
- [x] `redeem` 流程完成
- [x] 绑定 inviter / invitee / squad
- [x] 支持奖励状态 `pending`
- [x] 支持奖励状态 `granted`
- [x] 支持奖励状态 `rejected`

### 6.3 奖励规则最小落地

- [x] 定义一期奖励触发条件
- [x] 定义一期防重复发奖规则
- [x] 定义一期异常拒绝规则
- [x] 记录发奖日志或状态变更日志

### 6.4 本阶段收尾标准

- [ ] 能追溯“谁分享了谁邀请了谁谁领奖了”
- [ ] 奖励状态可查
- [ ] 不额外扩展复杂运营后台

## 7. Phase 4：风控与质量收尾

目标：在主链路可用后，把商用底线补齐。

### 7.1 风控

- [ ] 私密对象最小暴露策略完成
- [ ] 邀请链接撤销能力完成
- [ ] 邀请超次拦截完成
- [ ] 邀请过期拦截完成
- [ ] 重复领奖拦截完成
- [ ] 基础异常 UA / IP 规则预留完成

### 7.2 测试

- [ ] 后端 API tests 覆盖主链路
- [ ] 后端 API tests 覆盖邀请链路
- [ ] iOS UI tests 覆盖复制链接
- [ ] iOS UI tests 覆盖二维码页
- [ ] iOS UI tests 覆盖邀请入口
- [ ] 承接页 smoke tests 覆盖 OG / redirect / error states

### 7.3 发布前检查

- [ ] 域名、HTTPS、AASA 检查完成
- [ ] 核心页面入口回归完成
- [ ] 失效链接回归完成
- [ ] 奖励状态流转抽查完成

### 7.4 本阶段收尾标准

- [ ] MVP 可进入验收
- [ ] 没有未收尾的核心功能坑位
- [ ] 后续扩展点和当前已交付能力边界清晰

## 8. 当前建议开发顺序

### 8.1 大步骤

- [x] Step A：先落数据表和 BFF 主链路
- [x] Step B：再落 iOS `ShareLinkService` 和 `ShareCoordinator`
- [x] Step C：再接 Post / Event / News 的统一分享
- [x] Step D：再接个人名片 / 群名片 / 邀请
- [ ] Step E：最后补奖励状态、风控、测试

### 8.2 下一步最小编码切片

建议立刻开始的切片：

- [x] 梳理现有后端路由和 Prisma 结构
- [x] 设计 `share_links` / `share_link_events` / `invite_referrals` migration
- [x] 落第一版 BFF resolve API 和 code redirect 逻辑

## 9. 更新规则

每次开发推进后，必须同步更新：

- 本执行清单：更新 checkbox
- 开发日志：记录关键决策、重要风险、完成节点、变更原因

不要在主方案文档里追加过程性流水账。
