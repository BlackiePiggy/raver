# Backend Legacy

This directory is for compatibility code and historical routes that should not receive new business capabilities.

Use this directory for:

- old API compatibility adapters
- migration-only code
- historical integration adapters
- deprecated route wrappers

Rules:

- Legacy code must explain what replaces it.
- Legacy code should not be used by new features.
- Deleting legacy code requires checking all clients, workers, scripts, and data migration paths.
- Database deletion or cleanup requires `docs/DATABASE_BACKUP_GATEKEEPER.md`.

See:

- `docs/RAVER_LEGACY_AND_CURRENT_MAINLINE_INVENTORY.md`
