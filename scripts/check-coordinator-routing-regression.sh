#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
IOS_FEATURES_DIR="$ROOT_DIR/mobile/ios/RaverMVP/RaverMVP/Features"

CIRCLE_COORDINATOR="$IOS_FEATURES_DIR/Circle/Coordinator/CircleCoordinator.swift"
MESSAGES_COORDINATOR="$IOS_FEATURES_DIR/Messages/Coordinator/MessagesCoordinator.swift"
PROFILE_COORDINATOR="$IOS_FEATURES_DIR/Profile/Coordinator/ProfileCoordinator.swift"
DISCOVER_COORDINATOR="$IOS_FEATURES_DIR/Discover/Coordinator/DiscoverCoordinator.swift"
DISCOVER_ROUTE="$IOS_FEATURES_DIR/Discover/Coordinator/DiscoverRoute.swift"

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

check_hashable_conformance() {
  local file="$1"
  local enum_name="$2"
  if rg -q "enum[[:space:]]+$enum_name[[:space:]]*:[[:space:]]*Hashable" "$file"; then
    pass_check "$enum_name keeps Hashable conformance."
  else
    fail_check "$enum_name lost Hashable conformance in $file."
  fi
}

check_case_mappings() {
  local enum_name="$1"
  local enum_file="$2"
  local destination_file="$3"

  local cases
  cases="$(extract_enum_cases "$enum_file" "$enum_name" || true)"
  if [[ -z "$cases" ]]; then
    fail_check "No cases found for $enum_name in $enum_file."
    return
  fi

  local missing=()
  while IFS= read -r case_name; do
    [[ -z "$case_name" ]] && continue
    if ! rg -q "case[[:space:]]+let[[:space:]]+\\.$case_name\\b|case[[:space:]]+\\.$case_name\\b" "$destination_file"; then
      missing+=("$case_name")
    fi
  done <<< "$cases"

  if [[ "${#missing[@]}" -eq 0 ]]; then
    pass_check "$enum_name case-to-destination mapping is complete."
  else
    fail_check "$enum_name is missing destination mapping for: ${missing[*]}."
  fi
}

check_destination_binding() {
  local file="$1"
  local route_type="$2"
  if rg -q "navigationDestination\\(for:[[:space:]]*$route_type\\.self\\)" "$file"; then
    pass_check "$file binds NavigationStack to $route_type."
  else
    fail_check "$file does not bind NavigationStack to $route_type."
  fi
}

require_file "$CIRCLE_COORDINATOR"
require_file "$MESSAGES_COORDINATOR"
require_file "$PROFILE_COORDINATOR"
require_file "$DISCOVER_COORDINATOR"
require_file "$DISCOVER_ROUTE"

check_hashable_conformance "$CIRCLE_COORDINATOR" "CircleRoute"
check_hashable_conformance "$MESSAGES_COORDINATOR" "MessagesRoute"
check_hashable_conformance "$MESSAGES_COORDINATOR" "MessagesModalRoute"
check_hashable_conformance "$PROFILE_COORDINATOR" "ProfileRoute"
check_hashable_conformance "$DISCOVER_ROUTE" "DiscoverRoute"

check_destination_binding "$CIRCLE_COORDINATOR" "CircleRoute"
check_destination_binding "$MESSAGES_COORDINATOR" "MessagesRoute"
check_destination_binding "$PROFILE_COORDINATOR" "ProfileRoute"
check_destination_binding "$DISCOVER_COORDINATOR" "DiscoverRoute"

check_case_mappings "CircleRoute" "$CIRCLE_COORDINATOR" "$CIRCLE_COORDINATOR"
check_case_mappings "MessagesRoute" "$MESSAGES_COORDINATOR" "$MESSAGES_COORDINATOR"
check_case_mappings "MessagesModalRoute" "$MESSAGES_COORDINATOR" "$MESSAGES_COORDINATOR"
check_case_mappings "ProfileRoute" "$PROFILE_COORDINATOR" "$PROFILE_COORDINATOR"
check_case_mappings "DiscoverRoute" "$DISCOVER_ROUTE" "$DISCOVER_ROUTE"

if [[ "$failed" -ne 0 ]]; then
  echo "Coordinator routing regression checks failed."
  exit 1
fi

echo "All coordinator routing regression checks passed."
