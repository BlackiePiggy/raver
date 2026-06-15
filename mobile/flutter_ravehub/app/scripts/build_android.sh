#!/usr/bin/env bash
set -euo pipefail
flutter clean
flutter pub get
flutter build appbundle --release \
  --dart-define=FLAVOR=production \
  --dart-define=API_BASE_URL=https://api.ravehub.top \
  --obfuscate \
  --split-debug-info=build/debug-info/android
echo "Android AAB built: build/app/outputs/bundle/release/app-release.aab"
