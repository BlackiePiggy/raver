#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

exec xcodebuild \
  -workspace "$ROOT_DIR/RaverMVP.xcworkspace" \
  -scheme "RaverMVP" \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -sdk iphonesimulator \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  EXCLUDED_ARCHS=x86_64 \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build
