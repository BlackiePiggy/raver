#!/usr/bin/env bash
set -euo pipefail
# HarmonyOS HAP build via ohpm/hvigor
# Prerequisites: DevEco Studio installed, ohpm in PATH
flutter clean
flutter pub get
flutter build ohos --release \
  --dart-define=FLAVOR=production \
  --dart-define=API_BASE_URL=https://api.ravehub.top
echo "HarmonyOS HAP built: build/ohos/outputs/default/app-default-signed.hap"
