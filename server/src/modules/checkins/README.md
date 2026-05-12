# Check-ins Module

Status: Phase 2 target.

This module is the target home for Check-in v2, snapshots, projection read models, projection status, and projection workers.

Current source locations remain active:

```text
server/src/routes/checkins-v2.routes.ts
server/src/routes/checkin.routes.ts
server/src/controllers/checkin.controller.ts
server/src/services/checkin-domain.ts
server/src/services/checkin-overview.ts
server/src/services/checkin-projection.ts
server/src/services/checkin-projection-read-model.ts
server/src/services/checkin-projection-status.ts
server/src/services/checkin-projection-worker.ts
server/src/scripts/checkin-*.ts
```

Target ownership:

- Check-in write model operations
- Check-in snapshot generation
- Check-in selection normalization
- MyCheckins v2 projection read model
- Projection freshness status
- Projection worker orchestration
- Reproject / rebuild operational paths

Core models:

- `Checkin`
- `CheckinSnapshot`
- `CheckinSelection`
- `CheckinSelectionDJ`
- `UserCheckinTimelineEntry`
- `UserCheckinStat`
- `UserCheckinGalleryDJAggregate`
- `UserCheckinGalleryEventAggregate`
- `UserCheckinDerivedSignal`
- `CheckinOutboxEvent`

Migration rule:

Existing routes and scripts remain active until each path has a dedicated module service and verification. Database-changing operations must follow `docs/DATABASE_BACKUP_GATEKEEPER.md`.

Current facade:

```text
server/src/modules/checkins/index.ts
```

The facade currently re-exports the existing Check-in implementation. This keeps runtime behavior unchanged while giving routes and future jobs a stable module import path.
