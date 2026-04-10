#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
IOS_DIR="$ROOT_DIR/mobile/ios/RaverMVP/RaverMVP"
FEATURES_DIR="$IOS_DIR/Features"

if [[ ! -d "$IOS_DIR" ]]; then
  echo "error: iOS project directory not found: $IOS_DIR"
  exit 2
fi

failed=0

print_check() {
  local status="$1"
  local message="$2"
  echo "[$status] $message"
}

fail_with_results() {
  local message="$1"
  local results="$2"
  print_check "FAIL" "$message"
  echo "$results"
  failed=1
}

pass_check() {
  local message="$1"
  print_check "PASS" "$message"
}

# 1) Feature layer must not construct services via AppEnvironment factories.
feature_factory_hits="$(rg -n "AppEnvironment\\.makeService\\(|AppEnvironment\\.makeWebService\\(" "$FEATURES_DIR" || true)"
if [[ -n "$feature_factory_hits" ]]; then
  fail_with_results "Feature layer contains AppEnvironment service factory calls." "$feature_factory_hits"
else
  pass_check "Feature layer has no AppEnvironment service factory calls."
fi

# 2) AppState service-locator access should not be used after migration.
appstate_service_hits="$(rg -n "appState\\.service" "$IOS_DIR" || true)"
if [[ -n "$appstate_service_hits" ]]; then
  fail_with_results "Found AppState service-locator usage (appState.service)." "$appstate_service_hits"
else
  pass_check "No AppState service-locator usage found."
fi

# 3) AppEnvironment factory usage should be limited to app boot and AppContainer defaults.
disallowed_factory_hits="$(
  cd "$IOS_DIR"
  rg -n "AppEnvironment\\.makeService\\(|AppEnvironment\\.makeWebService\\(" . \
    -g '!RaverMVPApp.swift' \
    -g '!Application/DI/AppContainer.swift' || true
)"
if [[ -n "$disallowed_factory_hits" ]]; then
  fail_with_results "Found AppEnvironment factory calls outside allowed bootstrap files." "$disallowed_factory_hits"
else
  pass_check "AppEnvironment factory usage is limited to allowed bootstrap files."
fi

if [[ "$failed" -ne 0 ]]; then
  echo "Boundary checks failed."
  exit 1
fi

echo "All MVVM+Coordinator boundary checks passed."
