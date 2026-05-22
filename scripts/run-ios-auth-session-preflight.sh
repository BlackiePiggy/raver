#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

"$ROOT_DIR/scripts/check-ios-auth-session-guardrails.sh"

pnpm -C "$ROOT_DIR/server" auth:env:lint

echo "iOS auth session preflight passed."
