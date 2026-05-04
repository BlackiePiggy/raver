#!/usr/bin/env bash

set -euo pipefail

PROJECT_NAME="${PROJECT_NAME:-RaverMVP}"
DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-$HOME/Library/Developer/Xcode/DerivedData}"
MODULE_CACHE_ROOT="${MODULE_CACHE_ROOT:-$HOME/Library/Developer/Xcode/DerivedData/ModuleCache.noindex}"
SWIFTPM_CACHE_ROOT="${SWIFTPM_CACHE_ROOT:-$HOME/Library/Developer/Xcode/DerivedData/SourcePackages}"

say() {
  printf '\033[1;34m[fix-xcode-build-db]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[fix-xcode-build-db]\033[0m %s\n' "$*" >&2
}

kill_if_running() {
  local pattern="$1"
  if pgrep -f "$pattern" >/dev/null 2>&1; then
    say "Stopping processes matching: $pattern"
    pkill -f "$pattern" || true
  fi
}

remove_if_exists() {
  local path="$1"
  if [ -e "$path" ]; then
    say "Removing $path"
    rm -rf "$path"
  fi
}

say "Target project: $PROJECT_NAME"
say "DerivedData root: $DERIVED_DATA_ROOT"

kill_if_running "xcodebuild"
kill_if_running "XCBBuildService"
kill_if_running "SourceKitService"
kill_if_running "swift-frontend"
kill_if_running "clang"

sleep 1

say "Cleaning project-specific DerivedData folders"
while IFS= read -r derived_dir; do
  [ -z "$derived_dir" ] && continue
  remove_if_exists "$derived_dir"
done < <(find "$DERIVED_DATA_ROOT" -maxdepth 1 -type d -name "${PROJECT_NAME}-*" 2>/dev/null)

say "Cleaning project-specific build database leftovers"
while IFS= read -r db_path; do
  [ -z "$db_path" ] && continue
  remove_if_exists "$db_path"
done < <(find "$DERIVED_DATA_ROOT" \
  \( -path "*/${PROJECT_NAME}-*/Build/Intermediates.noindex/XCBuildData" \
     -o -path "*/${PROJECT_NAME}-*/Build/Intermediates.noindex/*.db" \
     -o -path "*/${PROJECT_NAME}-*/Build/Intermediates.noindex/*.db-shm" \
     -o -path "*/${PROJECT_NAME}-*/Build/Intermediates.noindex/*.db-wal" \) 2>/dev/null)

if [ "${CLEAR_MODULE_CACHE:-0}" = "1" ]; then
  warn "CLEAR_MODULE_CACHE=1 set, wiping ModuleCache.noindex"
  remove_if_exists "$MODULE_CACHE_ROOT"
fi

if [ "${CLEAR_SWIFTPM_CACHE:-0}" = "1" ]; then
  warn "CLEAR_SWIFTPM_CACHE=1 set, wiping DerivedData SourcePackages"
  remove_if_exists "$SWIFTPM_CACHE_ROOT"
fi

say "Done."
say "Recommended next steps:"
say "1. Fully quit Xcode if it is still open."
say "2. Reopen /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace"
say "3. Build again."

