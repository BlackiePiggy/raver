#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FEATURES_DIR="$ROOT_DIR/mobile/ios/RaverMVP/RaverMVP/Features"
FIXTURE_FILE="$ROOT_DIR/scripts/fixtures/coordinator-route-snapshots.sh"

DISCOVER_ROUTE="$FEATURES_DIR/Discover/Coordinator/DiscoverRoute.swift"
CIRCLE_COORDINATOR="$FEATURES_DIR/Circle/Coordinator/CircleCoordinator.swift"
MESSAGES_COORDINATOR="$FEATURES_DIR/Messages/Coordinator/MessagesCoordinator.swift"
PROFILE_COORDINATOR="$FEATURES_DIR/Profile/Coordinator/ProfileCoordinator.swift"

failed=0

print_check() {
  local status="$1"
  local message="$2"
  echo "[$status] $message"
}

pass_check() {
  print_check "PASS" "$1"
}

fail_check() {
  print_check "FAIL" "$1"
  failed=1
}

require_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    fail_check "Missing required file: $file"
    return 1
  fi
}

extract_enum_cases() {
  local file="$1"
  local enum_name="$2"

  awk -v enum_name="$enum_name" '
    BEGIN { in_enum = 0; depth = 0 }
    {
      if (!in_enum && $0 ~ ("enum[[:space:]]+" enum_name "[[:space:]]*:")) {
        in_enum = 1
      }
      if (in_enum) {
        line = $0
        opens = gsub(/\{/, "{", line)
        closes = gsub(/\}/, "}", line)
        depth += opens - closes

        if ($0 ~ /^[[:space:]]*case[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/) {
          case_line = $0
          sub(/^[[:space:]]*case[[:space:]]+/, "", case_line)
          split(case_line, parts, /[(:, ]/)
          if (parts[1] != "let" && parts[1] != "var") {
            print parts[1]
          }
        }

        if (depth <= 0) {
          exit
        }
      }
    }
  ' "$file" | sort -u
}

compare_snapshot() {
  local enum_name="$1"
  local enum_file="$2"

  local expected_var="SNAPSHOT_${enum_name}"
  local expected_raw
  expected_raw="$(eval "printf '%s' \"\${$expected_var:-}\"")"
  if [[ -z "$expected_raw" ]]; then
    fail_check "Snapshot fixture missing for $enum_name."
    return
  fi

  local actual_sorted
  actual_sorted="$(extract_enum_cases "$enum_file" "$enum_name" | tr '\n' ' ' | xargs)"

  local expected_sorted
  expected_sorted="$(tr ' ' '\n' <<< "$expected_raw" | sort -u | tr '\n' ' ' | xargs)"

  if [[ "$actual_sorted" == "$expected_sorted" ]]; then
    pass_check "$enum_name snapshot matches fixture."
  else
    fail_check "$enum_name snapshot mismatch.
  expected: $expected_sorted
  actual:   $actual_sorted"
  fi
}

require_file "$FIXTURE_FILE"
require_file "$DISCOVER_ROUTE"
require_file "$CIRCLE_COORDINATOR"
require_file "$MESSAGES_COORDINATOR"
require_file "$PROFILE_COORDINATOR"

# shellcheck disable=SC1090
source "$FIXTURE_FILE"

compare_snapshot "DiscoverRoute" "$DISCOVER_ROUTE"
compare_snapshot "CircleRoute" "$CIRCLE_COORDINATOR"
compare_snapshot "MessagesRoute" "$MESSAGES_COORDINATOR"
compare_snapshot "MessagesModalRoute" "$MESSAGES_COORDINATOR"
compare_snapshot "ProfileRoute" "$PROFILE_COORDINATOR"

if [[ "$failed" -ne 0 ]]; then
  echo "Coordinator route snapshot checks failed."
  exit 1
fi

echo "All coordinator route snapshot checks passed."
