# Backend Jobs

This directory is the target home for workers, schedulers, maintenance scripts, and recurring jobs.

Target categories:

```text
jobs/
  notification/
  checkin-projection/
  im-sync/
  imports/
  maintenance/
```

Rules:

- Job entrypoints should call module services.
- Do not duplicate domain business rules in job scripts.
- Jobs that mutate data must follow `docs/DATABASE_BACKUP_GATEKEEPER.md` when applicable.
- Jobs should record enough output to support operational debugging.

Current scripts in `server/src/scripts/` remain active until migrated.
