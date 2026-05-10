#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FEATURES_DIR="$ROOT_DIR/mobile/ios/RaverMVP/RaverMVP/Features"
APP_DIR="$ROOT_DIR/mobile/ios/RaverMVP/RaverMVP/Application"

DISCOVER_ROUTE="$FEATURES_DIR/Discover/Coordinator/DiscoverRoute.swift"
CIRCLE_COORDINATOR="$FEATURES_DIR/Circle/Coordinator/CircleCoordinator.swift"
MESSAGES_COORDINATOR="$FEATURES_DIR/Messages/Coordinator/MessagesCoordinator.swift"
PROFILE_COORDINATOR="$FEATURES_DIR/Profile/Coordinator/ProfileCoordinator.swift"
MAIN_TAB_COORDINATOR="$APP_DIR/Coordinator/MainTabCoordinator.swift"

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

require_pattern() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if rg -q "$pattern" "$file"; then
    pass_check "$message"
  else
    fail_check "$message"
  fi
}

# Critical cross-module routes are centralized in AppRoute and MainTabCoordinator.
require_pattern "$MAIN_TAB_COORDINATOR" "case[[:space:]]+eventDetail\\(" "AppRoute keeps eventDetail route case."
require_pattern "$MAIN_TAB_COORDINATOR" "case[[:space:]]+userProfile\\(" "AppRoute keeps userProfile route case."
require_pattern "$MAIN_TAB_COORDINATOR" "case[[:space:]]+squadProfile\\(" "AppRoute keeps squadProfile route case."
require_pattern "$MAIN_TAB_COORDINATOR" "case[[:space:]]+conversation\\(" "AppRoute keeps conversation route case."
require_pattern "$MAIN_TAB_COORDINATOR" "case[[:space:]]+let[[:space:]]+\\.eventDetail\\(|case[[:space:]]+\\.eventDetail\\(" "MainTabCoordinator destination maps eventDetail."
require_pattern "$MAIN_TAB_COORDINATOR" "case[[:space:]]+\\.eventDetail\\(" "MainTabCoordinator maps event deep links."
require_pattern "$MAIN_TAB_COORDINATOR" "case[[:space:]]+\\.userProfile\\(" "MainTabCoordinator destination maps userProfile."
require_pattern "$MAIN_TAB_COORDINATOR" "case[[:space:]]+\\.squadProfile\\(" "MainTabCoordinator destination maps squadProfile."
require_pattern "$MAIN_TAB_COORDINATOR" "case[[:space:]]+\\.conversation\\(" "MainTabCoordinator destination maps conversation."
require_pattern "$MESSAGES_COORDINATOR" "case[[:space:]]+squadProfile\\(" "MessagesModalRoute keeps squadProfile modal route case."

# Deep-link <-> route token round-trip checks for critical entry paths.
if ! swift - <<'SWIFT'
import Foundation

enum CriticalRouteToken: Equatable {
    case eventDetail(String)
    case userProfile(String)
    case squadProfile(String)
    case conversation(String)

    init?(url: URL) {
        guard (url.scheme ?? "").lowercased() == "raver" else { return nil }
        let host = (url.host ?? "").lowercased()
        let parts = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "event":
            guard parts.count == 1 else { return nil }
            self = .eventDetail(parts[0])
            return
        case "profile":
            guard parts.count == 1 else { return nil }
            self = .userProfile(parts[0])
            return
        case "squad":
            guard parts.count == 1 else { return nil }
            self = .squadProfile(parts[0])
            return
        case "messages":
            guard parts.count == 2, parts[0] == "conversation" else { return nil }
            self = .conversation(parts[1])
            return
        default:
            break
        }

        return nil
    }

    func url(hostOverride: String? = nil) -> URL? {
        let host: String
        let pathPrefix: String
        let rawID: String

        switch self {
        case let .eventDetail(eventID):
            host = hostOverride ?? "event"
            pathPrefix = ""
            rawID = eventID
        case let .userProfile(userID):
            host = hostOverride ?? "profile"
            pathPrefix = ""
            rawID = userID
        case let .squadProfile(squadID):
            host = hostOverride ?? "squad"
            pathPrefix = ""
            rawID = squadID
        case let .conversation(conversationID):
            host = hostOverride ?? "messages"
            pathPrefix = "conversation"
            rawID = conversationID
        }

        let encodedID = rawID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? rawID
        var components = URLComponents()
        components.scheme = "raver"
        components.host = host
        components.path = pathPrefix.isEmpty ? "/\(encodedID)" : "/\(pathPrefix)/\(encodedID)"
        return components.url
    }
}

let eventID = "evt_123-abc"
let userID = "usr_456-def"
let squadID = "sqd_789-ghi"
let conversationID = "c2c_usr_456-def"

let roundTripCases: [(CriticalRouteToken, [String])] = [
    (.eventDetail(eventID), ["event"]),
    (.userProfile(userID), ["profile"]),
    (.squadProfile(squadID), ["squad"]),
    (.conversation(conversationID), ["messages"]),
]

for (token, hosts) in roundTripCases {
    for host in hosts {
        guard let encoded = token.url(hostOverride: host) else {
            fputs("Round-trip encode failed for \(token) host \(host)\n", stderr)
            exit(1)
        }
        guard let decoded = CriticalRouteToken(url: encoded) else {
            fputs("Round-trip decode failed for \(encoded.absoluteString)\n", stderr)
            exit(1)
        }
        guard decoded == token else {
            fputs("Round-trip mismatch: encoded \(encoded.absoluteString), decoded \(decoded), expected \(token)\n", stderr)
            exit(1)
        }
    }
}

let invalidLinks = [
    "https://event/abc",
    "raver://event",
    "raver://messages/user/abc",
]

for raw in invalidLinks {
    guard let url = URL(string: raw) else {
        fputs("Invalid test URL literal: \(raw)\n", stderr)
        exit(1)
    }
    if CriticalRouteToken(url: url) != nil {
        fputs("Invalid link unexpectedly decoded: \(raw)\n", stderr)
        exit(1)
    }
}

print("Critical deep-link round-trip checks passed.")
SWIFT
then
  fail_check "Deep-link round-trip checks failed."
else
  pass_check "Deep-link round-trip checks passed."
fi

if [[ "$failed" -ne 0 ]]; then
  echo "Coordinator deep-link regression checks failed."
  exit 1
fi

echo "All coordinator deep-link regression checks passed."
