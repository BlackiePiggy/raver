# IM Module

> Status: Current + Migration
> Owner: Backend / Realtime
> Mainline: Tencent IM

This module is the backend boundary for Raver realtime messaging integration.

## Current Scope

- Tencent IM bootstrap and UserSig generation.
- Raver user to Tencent IM user mapping.
- Squad to Tencent IM group synchronization.
- Tencent IM friend import and system tip messages.
- Operational scripts for Tencent IM user sync and mapping export.

## Boundary Rules

- App routes, BFF routes, squad services, share invite redemption and scripts should import IM capabilities from `server/src/modules/im`.
- Tencent SDK-specific implementation can remain under `server/src/services/tencent-im/` during the migration period.
- OpenIM is not the current provider. Do not add new product behavior to OpenIM paths.
- Any IM data migration, batch sync apply, group relationship backfill or destructive cleanup must be preceded by a database backup and tracker entry.

## Provider Layout

```text
server/src/modules/im/
  index.ts              # Current module facade

server/src/services/tencent-im/
  tencent-im-client.ts  # Tencent REST client
  tencent-im-config.ts  # Provider configuration
  tencent-im-*.service.ts

server/src/services/openim/
  README.md             # Legacy / migration marker
```
