#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
IOS_DIR="$ROOT_DIR/mobile/ios/RaverMVP/RaverMVP"

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

scan_ios() {
  local pattern="$1"
  shift
  (
    cd "$IOS_DIR"
    rg -n "$pattern" . \
      -g '*.swift' \
      "$@" || true
  )
}

token_hits="$(
  scan_ios "SessionTokenStore\\.shared\\.(token|refreshToken)" \
    -g '!Core/SessionTokenStore.swift' \
    -g '!Core/ShareLinkService.swift' \
    -g '!Core/LiveSocialService.swift' \
    -g '!Core/LiveWebFeatureService.swift' \
    -g '!Core/AppState.swift' \
    -g '!Features/VirtualAssets/Services/LiveVirtualAssetRepository.swift' \
    -g '!Core/MockSocialService.swift'
)"
if [[ -n "$token_hits" ]]; then
  fail_with_results "Found direct SessionTokenStore token access outside auth-owned files." "$token_hits"
else
  pass_check "No direct SessionTokenStore token access outside auth-owned files."
fi

authorization_hits="$(
  scan_ios "Authorization\"|Authorization'" \
    -g '!Core/AuthenticatedRequestRunner.swift' \
    -g '!Core/ShareLinkService.swift' \
    -g '!Core/LiveSocialService.swift' \
    -g '!Core/LiveWebFeatureService.swift' \
    -g '!Features/VirtualAssets/Services/LiveVirtualAssetRepository.swift'
)"
if [[ -n "$authorization_hits" ]]; then
  fail_with_results "Found manual Authorization header usage outside auth request pipeline." "$authorization_hits"
else
  pass_check "No manual Authorization header usage outside auth request pipeline."
fi

session_expired_hits="$(
  scan_ios "raverSessionExpired" \
    -g '!Core/AppState.swift' \
    -g '!Core/ShareLinkService.swift' \
    -g '!Core/LiveSocialService.swift' \
    -g '!Core/LiveWebFeatureService.swift' \
    -g '!Features/VirtualAssets/Services/LiveVirtualAssetRepository.swift' \
    -g '!Core/MockSocialService.swift'
)"
if [[ -n "$session_expired_hits" ]]; then
  fail_with_results "Found direct raverSessionExpired usage outside auth-owned files." "$session_expired_hits"
else
  pass_check "No direct raverSessionExpired usage outside auth-owned files."
fi

urlsession_hits="$(
  scan_ios "URLSession\\.shared\\.data\\(|session\\.data\\(for:" \
    -g '!Core/AuthenticatedRequestRunner.swift' \
    -g '!Core/LiveSocialService.swift' \
    -g '!Core/LiveWebFeatureService.swift' \
    -g '!Core/ShareLinkService.swift' \
    -g '!Features/VirtualAssets/Services/LiveVirtualAssetRepository.swift' \
    -g '!Core/Widget/WidgetSelectableEventsSyncService.swift' \
    -g '!Features/Messages/MessagesHomeView.swift' \
    -g '!Features/Messages/UIKitChat/Support/DemoAlignedMessageActionCoordinator.swift' \
    -g '!Features/Profile/ProfileView.swift' \
    -g '!Features/Discover/Learn/Views/LearnModuleView.swift'
)"
if [[ -n "$urlsession_hits" ]]; then
  fail_with_results "Found direct URLSession request usage outside approved networking files." "$urlsession_hits"
else
  pass_check "No direct URLSession request usage outside approved networking files."
fi

if [[ "$failed" -ne 0 ]]; then
  cat <<'MSG'

iOS auth session guardrails failed.

New authenticated requests should go through the unified auth request pipeline.
If a match is intentional, either move the code behind the pipeline or add a narrow
exception to this script with a comment in the related PR explaining why it is safe.
MSG
  exit 1
fi

echo "iOS auth session guardrails passed."
