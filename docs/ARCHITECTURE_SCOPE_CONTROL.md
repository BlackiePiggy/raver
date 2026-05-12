# Architecture Scope Control

> Status: Active  
> Owner: Architecture  
> Last Updated: 2026-05-12  
> Applies To: 商用级架构改造全过程  
> Purpose: 防止架构改造过程中不断加入新功能、新想法和外扩需求，导致核心路线漂移。

## 1. 核心原则

本轮改造的目标是：

> 把 Raver 从快速迭代项目收束为结构清晰、领域边界明确、可多人协作、可商用运营的模块化单体。

本轮不是新功能开发周期。

## 2. 当前允许的核心路线

只允许处理以下事项：

- 后端模块化收束
- iOS feature / repository 收束
- 数据库领域分组和访问边界
- API 分区和 legacy 隔离
- IM 当前主线确认
- Notification / Check-in / Share / VirtualAsset 等既有核心能力结构化迁移
- Web/Admin 作为运营台的结构收束
- 文档入口、ADR、tracker、备份门禁、ownership 等架构治理基础

## 3. 默认暂缓的需求

以下需求默认不进入当前 Phase：

- 新推荐算法
- 新商业化玩法
- 新 UI 大改版
- 新第三方平台接入
- 新地图实时技术选型
- 微服务拆分
- 大规模数据库表重命名
- 与架构收束无关的性能优化
- 新活动玩法
- 新内容消费形态
- 新社交关系设计

这些需求可以记录，但不打断当前 Phase。

## 4. 新需求判定流程

任何新增需求先回答四个问题：

1. 是否直接服务当前 Phase 的架构收束目标？
2. 是否会扩大当前 Phase 的验证范围？
3. 是否会影响 Auth、IM、Notification、Check-in、Feed、数据库等核心链路稳定性？
4. 是否可以放入 backlog，等当前 Phase 完成后再评估？

判断规则：

| 结果 | 处理 |
| --- | --- |
| 明确服务当前 Phase，且风险低 | 可以进入当前 Phase |
| 服务当前 Phase，但风险高 | 单独拆 task，先写风险和验证计划 |
| 不服务当前 Phase | 进入 Backlog / Deferred |
| 不确定 | 进入 Backlog / Deferred，等待复盘 |

## 5. Backlog 记录位置

所有暂缓需求记录到：

```text
docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md
```

记录区：

```text
## 7. Backlog / Deferred
```

必须记录：

- 需求
- 来源
- 为什么暂缓
- 重新评估条件

## 6. 当前 Phase 变更规则

每个 Phase 开始前明确：

- 本 Phase 目标
- 本 Phase 不做什么
- 影响文件范围
- 验证命令
- 回滚策略

Phase 进行中如果出现新需求：

1. 先写入 Backlog / Deferred。
2. 不直接改代码。
3. 等当前 Phase 完成后再统一评估。

## 7. 防漂移 Checklist

每次开始任务前检查：

```md
### Scope Check

- [ ] 当前任务属于哪个 Phase：
- [ ] 当前任务是否服务该 Phase 目标：
- [ ] 是否新增产品功能：
- [ ] 是否扩大验证范围：
- [ ] 是否涉及数据库：
- [ ] 是否涉及核心链路：
- [ ] 是否需要进入 Backlog / Deferred：
```

## 8. 允许的小范围例外

以下情况可以作为当前任务的一部分：

- 为完成迁移必须调整 import path。
- 为维持兼容必须添加 adapter。
- 为验证迁移必须添加 smoke test。
- 为标记 legacy 必须添加注释或文档。
- 为避免编译失败必须做最小修复。

但这些例外必须保持最小范围，不顺手做额外重构。

## 9. 禁止事项

- 禁止借架构改造顺手做新产品功能。
- 禁止在迁移模块时重做 UI。
- 禁止在没有验收标准时扩大重构范围。
- 禁止在没有备份时做数据库动作。
- 禁止把 deferred backlog 当作当前任务列表。

## 10. Phase 0 状态

- [x] 新增需求防漂移规则已建立。
- [ ] 后续每个 Phase 开始前，需要在 tracker 中写 Scope Check。
