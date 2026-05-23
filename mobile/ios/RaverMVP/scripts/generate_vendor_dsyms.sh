#!/bin/sh
set -eu

if [ -z "${DWARF_DSYM_FOLDER_PATH:-}" ]; then
  echo "[vendor-dsyms] DWARF_DSYM_FOLDER_PATH is empty, skipping."
  exit 0
fi

if [ "${ACTION:-}" != "install" ]; then
  echo "[vendor-dsyms] Not archiving, skipping vendor dSYM generation."
  exit 0
fi

generate_dsym() {
  framework_name="$1"
  binary_path="$2"

  if [ ! -f "$binary_path" ]; then
    echo "[vendor-dsyms] warning: $framework_name binary not found at $binary_path"
    return 0
  fi

  temp_root="${DERIVED_FILE_DIR:-${TARGET_TEMP_DIR:-/tmp}}/VendorDSYMs"
  temp_dsym="$temp_root/$framework_name.framework.dSYM"
  output_dsym="$DWARF_DSYM_FOLDER_PATH/$framework_name.framework.dSYM"

  mkdir -p "$temp_root" "$DWARF_DSYM_FOLDER_PATH"
  rm -rf "$temp_dsym" "$output_dsym"

  echo "[vendor-dsyms] Generating $framework_name.framework.dSYM"
  dsymutil "$binary_path" -o "$temp_dsym"
  rsync -a --delete "$temp_dsym" "$DWARF_DSYM_FOLDER_PATH/"
}

generate_dsym \
  "GiphyUISDK" \
  "$SRCROOT/../../../thirdparty/giphy-ios-sdk/GiphyUISDK.xcframework/ios-arm64/GiphyUISDK.framework/GiphyUISDK"

generate_dsym \
  "ImSDK_Plus" \
  "$PODS_ROOT/TXIMSDK_Plus_iOS_XCFramework/ImSDK_Plus.xcframework/ios-arm64_armv7/ImSDK_Plus.framework/ImSDK_Plus"
