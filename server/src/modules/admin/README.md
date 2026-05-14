# Admin Module

> Status: Phase 6 P1 facade
> Owner: Backend / Operations
> Route Prefix: `/api/admin/v1`

This module is the backend boundary for Admin / Operations entrypoints.

## Current Scope

Phase 6 P1 only creates a stable Admin API facade. It does not move domain
business logic, change response payloads, or create new database tables.

Current facade targets:

- Admin status aggregation.
- Admin audit log query.
- Notification Center admin operations.
- Pre-registration operations.
- Check-in projection status.
- Virtual asset grants.
- Shared admin / operator role policy.
- Shared admin audit write service backed by existing `admin_audit_logs`.

## Boundary Rules

- Existing legacy/current routes remain mounted and compatible.
- Admin facade routes should call existing domain routes or domain ops services.
- Do not add product features from this module.
- Do not put domain business rules in the Admin module.
- `AdminAuditLog`, RBAC tables, data migration, projection rebuild, snapshot
  rebuild, IM sync apply, and batch repair work require database backup first.

## Current Layout

```text
server/src/modules/admin/
  admin-auth.policy.ts
  admin-audit.service.ts
  admin-status.service.ts
  admin.routes.ts  # /api/admin/v1 facade router
  index.ts         # module export
  README.md
```

P2 has added shared admin auth / role policy for current Admin / Operations
entrypoints. P3 confirmed `AdminAuditLog` already exists in schema and
migration history, then added a shared audit service for current sensitive
Admin / Operations writes without changing database schema.

P3 also exposes read-only audit log query at:

```text
GET /api/admin/v1/audit-logs
```

P4 adds a read-only Admin status aggregation endpoint. It combines existing
Notification Center status, APNs configuration, notification outbox worker
configuration, and Check-in projection freshness without triggering workers,
projection rebuilds, or data repair:

```text
GET /api/admin/v1/status
```
