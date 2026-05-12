# ADR-0005 Modular Monolith Before Microservices

## Status

Accepted

## Context

Raver 已经具备平台级业务复杂度，但当前最大问题不是独立部署或横向扩容，而是：

- 领域边界不清
- routes / services / scripts 横向平铺
- iOS service 命名和职责过大
- 数据库模型缺少 owner
- 历史路线未隔离

如果现在直接拆微服务，会放大接口、部署、数据一致性和运维复杂度。

## Decision

当前阶段采用 modular monolith，而不是微服务拆分。

后端优先整理为：

```text
server/src/modules/
server/src/shared/
server/src/infrastructure/
server/src/jobs/
server/src/legacy/
```

## Consequences

- 保留 Express + TypeScript + Prisma 技术基线。
- 先按领域收拢模块，再考虑服务拆分。
- 每个 module 有 routes、controller、service、repository、policy、dto、mapper 的清晰边界。
- Worker 和 external integration 也按模块归属组织。

## Migration Notes

- Phase 1 建立模块骨架。
- Phase 2 起逐步迁移边界清晰模块。
- 只有当模块边界稳定且出现明确规模瓶颈时，再重新评估微服务拆分。
