# Share Module

Status: Phase 2 target.

This module is the target home for share links, deep links, QR/poster rendering, share events, invite referrals, and share smoke paths.

Current source locations remain active:

```text
server/src/routes/share.routes.ts
server/src/services/share-link.service.ts
server/src/scripts/share-link-smoke.ts
server/src/scripts/share-invite-smoke.ts
```

Target ownership:

- Share link creation and resolution
- Share landing pages
- Universal link / deep link fallback metadata
- QR and poster endpoints
- Share event recording
- Invite referral redemption

Core models:

- `ShareLink`
- `ShareLinkEvent`
- `InviteReferral`

Migration rule:

Existing public share routes remain stable. The module facade should be used as the import path before deeper refactors, because these endpoints are public-facing and should avoid behavioral churn.

Current facade:

```text
server/src/modules/share/index.ts
```

The facade currently re-exports the existing share link implementation. This keeps runtime behavior unchanged while giving routes and future jobs a stable module import path.
