# Shared Backend Utilities

This directory is for cross-domain backend utilities that are not owned by a single business module.

Allowed categories:

- auth middleware helpers
- request context
- error types
- HTTP response helpers
- pagination helpers
- validation helpers
- logging helpers
- config loading
- common types

Rules:

- Do not put domain business logic here.
- Do not add Prisma model-specific logic here.
- If a helper only belongs to one domain, keep it in `modules/<module>/`.
- If a helper wraps a third-party SDK, place it in `infrastructure/`.
