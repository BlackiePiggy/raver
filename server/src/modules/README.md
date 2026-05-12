# Backend Modules

This directory is the target home for Raver backend domain modules.

The backend is being reorganized as a modular monolith. Existing routes, controllers, services, and scripts remain in place during migration; new or migrated domain code should move here gradually.

Target module shape:

```text
modules/<module>/
  <module>.routes.ts
  <module>.controller.ts
  <module>.service.ts
  <module>.repository.ts
  <module>.policy.ts
  <module>.dto.ts
  <module>.mapper.ts
  <module>.types.ts
  <module>.jobs.ts
  index.ts
```

Rules:

- Do not add unrelated cross-domain services here.
- Keep HTTP concerns in routes/controllers.
- Keep Prisma access in repositories.
- Keep permissions and visibility checks in policies.
- Keep third-party SDK wrappers in `../infrastructure`.
- Keep workers and schedulers in `../jobs` unless they are tiny module-local entrypoints.
- Legacy compatibility should live in `../legacy` or be clearly marked.

See:

- `docs/RAVER_BACKEND_MODULE_OWNERSHIP.md`
- `docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_PLAN.md`
