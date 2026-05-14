# OpenIM Legacy Marker

> Status: Legacy / Migration
> Owner: Backend / Realtime

OpenIM is retained only as historical and migration context. Tencent IM is the current IM provider for Raver.

Rules:

- Do not add new product behavior here.
- Do not route new App, Admin or worker code through OpenIM.
- Keep only migration, audit, rollback or reference material that is still useful.
- Before any cleanup that touches OpenIM-related database rows, snapshots or migration tables, create and verify a database backup and record it in `docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md`.
