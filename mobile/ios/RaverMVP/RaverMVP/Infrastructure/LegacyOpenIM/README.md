# Legacy OpenIM Runtime

> Status: Legacy / Migration
> Mainline: Tencent IM

This directory is retained only for historical compatibility, migration review and rollback reference.

Rules:

- Do not add new product behavior here.
- Do not route new app features through `IMSession`.
- Current IM bootstrap, conversation sync, message transport and squad group behavior must use `Infrastructure/TencentIM`.
- Before any cleanup that touches OpenIM-related database rows, snapshots, migration tables or historical sync jobs, create and verify a database backup and record it in `docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md`.
