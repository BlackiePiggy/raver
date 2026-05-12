# ADR-0002 Tencent IM As Current IM Provider

## Status

Accepted

## Context

Raver 的聊天和会话能力经历过 OpenIM 相关探索，仓库和文档中仍保留 OpenIM、ChatLayout、迁移计划和运行手册。

当前真实主线已经转向 Tencent IM。后端存在 `server/src/services/tencent-im/` 和 `/v1/im/tencent` 路由，iOS 也围绕 IM bootstrap、usersig、会话、消息渲染和 UIKitChat 进行集成。

## Decision

Tencent IM 是当前 IM 主线。OpenIM 相关内容作为历史、迁移或兼容参考处理。

## Consequences

- 新 IM 能力优先进入 Tencent IM 集成路径。
- OpenIM 不再作为新能力扩展目标。
- 后端 `im` module 应收拢 Tencent IM integration。
- OpenIM 相关模型、文档、脚本需要标记为 legacy / migration。

## Migration Notes

- Phase 4 中收束后端 `im` module。
- iOS 侧将 SDK 会话、store、media resolver 收拢到 `Infrastructure/TencentIM/`。
- OpenIM 文档保留历史价值，但在 docs index 中明确不是当前主线。
