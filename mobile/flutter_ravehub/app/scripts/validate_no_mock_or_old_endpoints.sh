#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SOURCE_PATHS=(
  "$ROOT_DIR/app/lib"
  "$ROOT_DIR/packages"
)

RG_ARGS=(
  -n
  -g '*.dart'
  -g '!**/.dart_tool/**'
  -g '!**/build/**'
  -g '!**/test/**'
)

old_endpoint_matches="$(
  rg "${RG_ARGS[@]}" \
    '(/v1/social|v1/social|/v1/content-submissions|v1/content-submissions)' \
    "${SOURCE_PATHS[@]}" || true
)"

mock_matches="$(
  rg "${RG_ARGS[@]}" \
    '(\bmock(ed|s|ing)?\b|\bMock[A-Za-z0-9_]*\b|\bfake[A-Za-z0-9_]*\b|\bFake[A-Za-z0-9_]*\b|\bdemo[A-Za-z0-9_]*\b|\bDemo[A-Za-z0-9_]*\b|\bfixture[A-Za-z0-9_]*\b|\bFixture[A-Za-z0-9_]*\b)' \
    "${SOURCE_PATHS[@]}" || true
)"

user_visible_placeholder_matches="$(
  rg "${RG_ARGS[@]}" \
    "['\"][^'\"]*(TODO|FIXME|coming soon|not implemented|placeholder action|敬请期待|暂未开放|占位|假数据|模拟数据)[^'\"]*['\"]" \
    "${SOURCE_PATHS[@]}" || true
)"

if [[ -n "$old_endpoint_matches" ]]; then
  echo "Old endpoint patterns found in production Dart sources:" >&2
  printf '%s\n' "$old_endpoint_matches" >&2
  exit 1
fi

if [[ -n "$mock_matches" ]]; then
  echo "Mock/fake/demo data patterns found in production Dart sources:" >&2
  printf '%s\n' "$mock_matches" >&2
  exit 1
fi

if [[ -n "$user_visible_placeholder_matches" ]]; then
  echo "User-visible TODO/placeholder strings found in production Dart sources:" >&2
  printf '%s\n' "$user_visible_placeholder_matches" >&2
  exit 1
fi

echo "No mock/fake/demo production code, old endpoint patterns, or user-visible placeholder strings found."
