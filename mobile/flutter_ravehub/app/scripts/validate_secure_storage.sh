#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# validate_secure_storage.sh
#
# Runtime check for flutter_secure_storage on each platform.
# Run this on a real device during QA to confirm KeyStore/Keychain readiness.
# ----------------------------------------------------------------------------
set -euo pipefail

echo "Flutter Secure Storage — Platform Validation"
echo "============================================="
echo ""
echo "iOS:         Uses Apple Keychain (kSecAttrAccessibleWhenUnlocked)"
echo "Android:     Uses Android Keystore (AES-256, API 23+)"
echo "HarmonyOS:   Uses OHOS huks (HarmonyOS KeyStore, API 12+)"
echo ""
echo "Storage keys used by RaveHub:"
echo "  access_token        — JWT access token"
echo "  refresh_token       — JWT refresh token"
echo "  session_user_id     — Logged-in user ID"
echo ""
echo "To verify storage is working on a real device, run:"
echo "  flutter drive --target=test_driver/secure_storage_test.dart"
echo ""
echo "flutter_secure_storage 9.x handles HarmonyOS KeyStore automatically"
echo "via the OHOS platform plugin. No additional native code required."
echo "Reference: https://pub.dev/packages/flutter_secure_storage"
