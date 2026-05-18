#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BRANCH="${BRANCH:-codex/youtube-set}"
API_NAME="${API_NAME:-raver-api}"
WEB_NAME="${WEB_NAME:-raver-web}"
WEBTOOL_NAME="${WEBTOOL_NAME:-raver-webtool}"
API_PORT="${API_PORT:-3901}"
WEBTOOL_PORT="${WEBTOOL_PORT:-8000}"

echo "🚀 Raver deploy update"
echo "branch: $BRANCH"
echo ""

cd "$ROOT_DIR"
git fetch origin
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"

echo ""
echo "📦 update server"
cd "$ROOT_DIR/server"
pnpm install
pnpm prisma migrate deploy
pnpm prisma generate
pnpm build
pm2 restart "$API_NAME" --update-env || pm2 start "pnpm start" --name "$API_NAME"

echo ""
echo "🌐 update web"
cd "$ROOT_DIR/web"
pnpm install
pnpm build
pm2 restart "$WEB_NAME" --update-env || pm2 start "pnpm start" --name "$WEB_NAME"

echo ""
echo "🧰 update festival-viewer"
cd "$ROOT_DIR/scrapRave"
pm2 restart "$WEBTOOL_NAME" --update-env || pm2 start "python3 web_tool/server.py" --name "$WEBTOOL_NAME"

echo ""
echo "✅ deploy finished"
echo "API:   pm2 logs $API_NAME --lines 100"
echo "Web:   pm2 logs $WEB_NAME --lines 100"
echo "Tool:  pm2 logs $WEBTOOL_NAME --lines 100"
echo "Ports: $API_PORT / $WEBTOOL_PORT / 3000"
