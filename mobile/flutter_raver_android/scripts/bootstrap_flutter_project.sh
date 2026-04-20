#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PARENT="$ROOT_DIR/app"
APP_DIR="$APP_PARENT/raver_android"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter command not found."
  echo "Install Flutter SDK first, then run: flutter doctor -v"
  echo "See docs/RAVER_FLUTTER_ANDROID_TECHNICAL_PLAN.md for the full setup route."
  exit 1
fi

mkdir -p "$APP_PARENT"

if [ ! -d "$APP_DIR" ]; then
  flutter create \
    --org com.raver \
    --project-name raver_android \
    --platforms android \
    "$APP_DIR"
fi

cd "$APP_DIR"

flutter pub add \
  flutter_riverpod \
  go_router \
  dio \
  retrofit \
  json_annotation \
  freezed_annotation \
  cached_network_image \
  flutter_secure_storage \
  shared_preferences \
  drift \
  sqlite3_flutter_libs \
  path_provider \
  path \
  intl \
  image_picker \
  permission_handler \
  video_player \
  chewie \
  just_audio \
  package_info_plus \
  connectivity_plus \
  device_info_plus \
  url_launcher

flutter pub add --dev \
  build_runner \
  drift_dev \
  retrofit_generator \
  json_serializable \
  freezed \
  flutter_lints \
  mocktail \
  golden_toolkit

mkdir -p \
  lib/app/router \
  lib/app/di \
  lib/core/config \
  lib/core/design_system \
  lib/core/networking \
  lib/core/persistence \
  lib/core/platform \
  lib/core/widgets \
  lib/features/auth \
  lib/features/discover \
  lib/features/circle \
  lib/features/messages \
  lib/features/profile \
  lib/features/media \
  integration_test

echo "Flutter project is ready at: $APP_DIR"
echo "Next: flutter doctor -v && flutter run -d emulator"
