#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/mobile/ios/RaverMVP"
WORKSPACE_PATH="$IOS_DIR/RaverMVP.xcworkspace"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/raver-event-contract-ci-derived}"
SCHEME="RaverMVP"
TEST_FILTERS=(
  "-only-testing:RaverMVPTests/EventContractParityTests"
  "-only-testing:RaverMVPTests/EventLineupDraftDerivationTests"
  "-only-testing:RaverMVPTests/EventUploadMultiWeekModelTests"
)

resolve_simulator_name() {
  if [[ -n "${IOS_SIMULATOR_NAME:-}" ]]; then
    echo "$IOS_SIMULATOR_NAME"
    return
  fi

  local candidates=(
    "iPhone 17"
    "iPhone 17 Pro"
    "iPhone 16 Pro"
    "iPhone 16"
  )

  local available
  available="$(xcrun simctl list devices available)"

  local candidate
  for candidate in "${candidates[@]}"; do
    if grep -Fq "$candidate" <<<"$available"; then
      echo "$candidate"
      return
    fi
  done

  echo "Unable to find a supported iOS simulator. Available devices:"
  echo "$available"
  exit 1
}

SIMULATOR_NAME="$(resolve_simulator_name)"
DESTINATION="platform=iOS Simulator,name=$SIMULATOR_NAME"

echo "Using simulator: $SIMULATOR_NAME"

xcodebuild build-for-testing \
  -quiet \
  -workspace "$WORKSPACE_PATH" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -skipPackagePluginValidation \
  "${TEST_FILTERS[@]}" \
  COMPILER_INDEX_STORE_ENABLE=NO

XCTESTRUN_PATH="$(find "$DERIVED_DATA_PATH/Build/Products" -name '*.xctestrun' | head -n 1)"

if [[ -z "$XCTESTRUN_PATH" ]]; then
  echo "Failed to locate .xctestrun inside $DERIVED_DATA_PATH/Build/Products"
  exit 1
fi

xcodebuild test-without-building \
  -quiet \
  -xctestrun "$XCTESTRUN_PATH" \
  -destination "$DESTINATION" \
  "${TEST_FILTERS[@]}"

echo "iOS Event contract parity tests passed."
