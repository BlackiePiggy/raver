# Cloudflare Backend Deployment

This backend is best deployed to Cloudflare with **Cloudflare Containers**, not as a pure Worker.

The current server is an Express + Prisma modular monolith. It uses PostgreSQL, Node-only libraries, local filesystem uploads, APNs/Firebase/Tencent IM integrations, background schedulers, and runtime file reads. A direct Worker rewrite would be a larger migration. Containers let Cloudflare host the existing Node service with the least application risk.

## Architecture

```text
client
  -> Cloudflare Worker: cloudflare/backend
  -> Durable Object: RaverBackendContainer
  -> Container: server/Dockerfile running node dist/index.js on port 3901
  -> External PostgreSQL and object storage/services
```

## Requirements

- Cloudflare Workers Paid plan with Containers enabled.
- Wrangler authenticated with the target Cloudflare account.
- A production PostgreSQL database reachable from Cloudflare.
- Production secrets configured in Cloudflare. Do not commit `.env`.
- Upload/media storage moved to object storage before production traffic if uploaded files must persist across container restarts.

## Files

- `server/Dockerfile` builds the current Express API into a production Node image.
- `server/.dockerignore` keeps local secrets, uploads, build output, and dependencies out of the image context.
- `cloudflare/backend/wrangler.jsonc` defines the Worker, Durable Object binding, and container image.
- `cloudflare/backend/src/index.ts` proxies all requests to one named backend container instance.

## Setup

Install Worker deployment dependencies:

```bash
cd cloudflare/backend
pnpm install
```

Log in:

```bash
pnpm exec wrangler login
```

Set production secrets:

```bash
pnpm exec wrangler secret put DATABASE_URL
pnpm exec wrangler secret put JWT_SECRET
pnpm exec wrangler secret put REFRESH_TOKEN_SECRET
```

Then add the service-specific secrets used by enabled features, for example Tencent IM, Firebase, APNs, Ali OSS, Spotify, Discogs, SoundCloud, and Coze enrichment keys.

## Deploy

```bash
cd cloudflare/backend
pnpm deploy
```

Wrangler builds `server/Dockerfile`, uploads the image to Cloudflare's registry, deploys the Worker, and routes requests through the container-enabled Durable Object.

Health check:

```bash
curl https://raver-backend.<your-subdomain>.workers.dev/health
```

## Local Build Verification

When local network access to npm or Docker Hub is slow, use the system proxy on port `7897` for Node package commands:

```bash
HTTP_PROXY=http://127.0.0.1:7897 \
HTTPS_PROXY=http://127.0.0.1:7897 \
ALL_PROXY=http://127.0.0.1:7897 \
pnpm install
```

After the base image is available locally, this verifies the backend image without asking Docker Hub for fresh metadata:

```bash
docker pull node:22-bookworm-slim
docker build --pull=false -f server/Dockerfile server
```

## Important Production Notes

- `max_instances` is currently `1` because the server starts in-process schedulers. Raising it can duplicate notification jobs and enrichment workers unless those jobs are moved to a single-owner scheduler or queue.
- Container local disk is not a durable media store. Existing `/uploads` endpoints can work for temporary files, but production uploads should be backed by Ali OSS, Cloudflare R2, or another object store.
- Keep PostgreSQL external for now. Migrating this schema to D1 is not a drop-in change because the Prisma datasource is PostgreSQL and the schema uses PostgreSQL-oriented modeling.
- Run migrations separately against the production database before deploying application code that depends on new columns or tables.
- If a route depends on private key files, prefer injecting the key content through secrets where the code already supports that. File paths inside the container require bundling or mounting the file deliberately.
