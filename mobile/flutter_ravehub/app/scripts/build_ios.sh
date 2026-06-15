#!/usr/bin/env bash
set -euo pipefail
flutter clean
flutter pub get
flutter build ipa --release \
  --dart-define=FLAVOR=production \
  --dart-define=API_BASE_URL=https://api.ravehub.top \
  --export-options-plist=ios/ExportOptions.plist
echo "iOS IPA built: build/ios/ipa/ravehub.ipa"
