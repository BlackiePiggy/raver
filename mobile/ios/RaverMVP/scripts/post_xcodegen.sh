#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
IOS_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

POD_BIN=""
if command -v pod >/dev/null 2>&1; then
  POD_BIN="$(command -v pod)"
elif [ -x "$HOME/.gem/ruby/2.6.0/bin/pod" ]; then
  POD_BIN="$HOME/.gem/ruby/2.6.0/bin/pod"
fi

if [ -z "$POD_BIN" ]; then
  echo "[post_xcodegen] CocoaPods not found. Install pods then run: pod install"
  exit 0
fi

echo "[post_xcodegen] Using pod at: $POD_BIN"
cd "$IOS_ROOT"
"$POD_BIN" install
