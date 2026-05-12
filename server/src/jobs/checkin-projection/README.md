# Check-in Projection Jobs

This directory is the target home for Check-in projection workers and operational entrypoints.

Current package scripts remain unchanged and continue to call files in `server/src/scripts/`. Those script files should be thin wrappers around job entrypoints here.

Rules:

- Default commands must be safe to run repeatedly.
- Apply-style operations must follow `docs/DATABASE_BACKUP_GATEKEEPER.md`.
- Job code should call `modules/checkins` instead of reaching into legacy service paths.
- Temporary verification files created while testing must be deleted after validation unless they are formal backups or tracker records.
