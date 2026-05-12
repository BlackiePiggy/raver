# ADR-0006 Admin Console Over Public Web First

## Status

Accepted

## Context

仓库中存在 `web/`，包含活动、社区、DJ、Set、预报名和 Admin 页面。早期 README 容易让人误解 Web 是当前主产品入口。

当前真实产品主线是 iOS App。Web 更适合承载：

- Admin Console
- CMS / operation workflows
- Pre-registration website
- Public fallback pages
- Legacy web frontend

## Decision

Web 当前定位为 Admin / CMS / Public fallback，而不是主产品客户端。

## Consequences

- Web 改造优先围绕后台运营和公开 fallback。
- App 用户体验优先在 iOS 中演进。
- Admin API 应逐步统一到 `/api/admin/v1`。
- Web-first 相关旧口径需要标记为 legacy。

## Migration Notes

- Phase 6 将 Web/Admin 从页面集合升级为运营系统。
- 根 README 和 docs index 中明确 Web 的当前定位。
- Public pages 和 Admin Console 在目录上逐步区分。
