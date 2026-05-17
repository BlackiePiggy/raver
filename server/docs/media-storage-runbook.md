# Media Storage Runbook

The backend stores uploaded media in OSS and tracks each object in `media_assets`.
Local `server/uploads` is only a development fallback and production startup fails
when OSS is not configured.

## Required production configuration

Set these environment variables before starting the server:

```sh
OSS_REGION=...
OSS_ACCESS_KEY_ID=...
OSS_ACCESS_KEY_SECRET=...
OSS_BUCKET=...
OSS_ENDPOINT=... # optional
```

Do not set `ALLOW_LOCAL_UPLOAD_STORAGE=true` or `ALLOW_LOCAL_UPLOAD_STATIC=true`
in production unless you are doing an explicit emergency rollback.

## Deploy checklist

1. Apply migrations:

```sh
set -a && source .env && set +a
DIRECT_URL="${DIRECT_URL:-$DATABASE_URL}" pnpm prisma migrate deploy
```

2. Build the server:

```sh
pnpm build
```

3. Check production boot has OSS configured. The process exits when `NODE_ENV=production`
and the required OSS variables are missing.

## Migrating existing local uploads

Dry run:

```sh
pnpm media:uploads:migrate-oss -- --limit=500
```

Apply in batches:

```sh
pnpm media:uploads:migrate-oss:apply -- --limit=50
```

The script uploads `/uploads/...` files to OSS, updates business records to OSS URLs,
and creates `media_assets` records.

## Reconciling media asset records

If a previous migration updated business URLs but did not create every
`media_assets` row, run reconcile mode.

Dry run:

```sh
pnpm media:uploads:migrate-oss -- --reconcile --limit=500
```

Apply:

```sh
pnpm media:uploads:migrate-oss:apply -- --reconcile --limit=500
```

Reconcile mode only registers missing `media_assets` rows for legacy OSS URLs. It
does not change business records or upload files.

## Operations

Summary:

```http
GET /api/admin/v1/media-assets/summary
```

List:

```http
GET /api/admin/v1/media-assets?status=active&limit=100
```

Manual purge:

```http
POST /api/admin/v1/media-assets/purge
Content-Type: application/json

{ "limit": 20 }
```

The purge scheduler deletes OSS objects for assets marked `replaced` or `deleted`
and then marks them `purged`. Failed purges are retried with backoff and surfaced
in the summary endpoint.
