#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_DIR="$ROOT_DIR/web"
SOURCE_SPEC="$ROOT_DIR/contracts/openapi/event-admin.v1.yaml"
IOS_SPEC="$ROOT_DIR/mobile/ios/RaverMVP/Packages/RaverEventAdminContract/Sources/RaverEventAdminContract/openapi.yaml"
WEB_GENERATED="$ROOT_DIR/contracts/generated/web/event-admin.ts"

if ! diff -u "$SOURCE_SPEC" "$IOS_SPEC" >/tmp/raver-event-admin-ios-spec.diff; then
  echo "Event admin OpenAPI source and iOS package copy are out of sync:"
  cat /tmp/raver-event-admin-ios-spec.diff
  exit 1
fi

pushd "$WEB_DIR" >/dev/null
pnpm run generate:contracts:event >/tmp/raver-event-admin-generate.log
popd >/dev/null

if ! git -C "$ROOT_DIR" diff --exit-code -- "$WEB_GENERATED" >/tmp/raver-event-admin-web-generated.diff; then
  echo "Generated web Event contract is stale. Re-run 'pnpm --dir web run generate:contracts:event':"
  cat /tmp/raver-event-admin-web-generated.diff
  exit 1
fi

echo "Event admin contract sync check passed."
