#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BRANCH="${BRANCH:-codex/youtube-set}"
API_NAME="${API_NAME:-raver-api}"
WEB_NAME="${WEB_NAME:-raver-web}"
WEBTOOL_NAME="${WEBTOOL_NAME:-raver-webtool}"
API_PORT="${API_PORT:-3901}"
WEBTOOL_PORT="${WEBTOOL_PORT:-8000}"
WEBTOOL_CACHE_ROOT="${WEBTOOL_CACHE_ROOT:-$HOME/raver-cache/dj_source_cache}"
WEBTOOL_CACHE_MAX_BYTES="${WEBTOOL_CACHE_MAX_BYTES:-2G}"

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
if [ -d "$ROOT_DIR/scrapRave" ] && [ -f "$ROOT_DIR/scrapRave/web_tool/server.py" ]; then
  cd "$ROOT_DIR/scrapRave"
  mkdir -p "$WEBTOOL_CACHE_ROOT"
  export RAVER_BFF_BASE="http://127.0.0.1:$API_PORT"
  export DJ_SOURCE_CACHE_ROOT="$WEBTOOL_CACHE_ROOT"
  export DJ_SOURCE_CACHE_MAX_BYTES="$WEBTOOL_CACHE_MAX_BYTES"
  pm2 restart "$WEBTOOL_NAME" --update-env \
    || pm2 start web_tool/server.py --name "$WEBTOOL_NAME" --interpreter python3 --update-env
else
  echo "⚠️  skip festival-viewer: $ROOT_DIR/scrapRave/web_tool/server.py not found"
  echo "   当前 git 仓库没有跟踪 scrapRave 目录；如果线上需要 festival-viewer，需要先把 scrapRave 纳入部署包或单独上传到服务器。"
fi

echo ""
echo "✅ deploy finished"
echo "API:   pm2 logs $API_NAME --lines 100"
echo "Web:   pm2 logs $WEB_NAME --lines 100"
echo "Tool:  pm2 logs $WEBTOOL_NAME --lines 100"
echo "Ports: $API_PORT / $WEBTOOL_PORT / 3000"
