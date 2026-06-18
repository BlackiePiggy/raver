#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

matches="$(
  rg -n '(/v1/social|v1/social)' \
    "$ROOT_DIR/app/lib" \
    "$ROOT_DIR/packages" \
    -g '*.dart' \
    -g '!**/.dart_tool/**' \
    -g '!**/build/**' || true
)"

if [[ -n "$matches" ]]; then
  echo "Legacy /v1/social endpoints found:" >&2
  printf '%s\n' "$matches" >&2
  exit 1
fi

echo "No legacy /v1/social endpoints found."
