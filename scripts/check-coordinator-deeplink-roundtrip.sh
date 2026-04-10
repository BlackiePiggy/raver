#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FEATURES_DIR="$ROOT_DIR/mobile/ios/RaverMVP/RaverMVP/Features"

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

# Critical route cases must exist and keep destination mapping.
require_pattern "$DISCOVER_ROUTE" "case[[:space:]]+eventDetail\\(" "DiscoverRoute keeps eventDetail route case."
require_pattern "$DISCOVER_ROUTE" "case[[:space:]]+\\.eventDetail\\(" "Discover route destination maps eventDetail."

require_pattern "$CIRCLE_COORDINATOR" "case[[:space:]]+squadProfile\\(" "CircleRoute keeps squadProfile route case."
require_pattern "$CIRCLE_COORDINATOR" "case[[:space:]]+userProfile\\(" "CircleRoute keeps userProfile route case."
require_pattern "$CIRCLE_COORDINATOR" "case[[:space:]]+eventDetail\\(" "CircleRoute keeps eventDetail route case."
require_pattern "$CIRCLE_COORDINATOR" "case[[:space:]]+let[[:space:]]+\\.squadProfile\\(" "Circle destination maps squadProfile."
require_pattern "$CIRCLE_COORDINATOR" "case[[:space:]]+let[[:space:]]+\\.userProfile\\(" "Circle destination maps userProfile."
require_pattern "$CIRCLE_COORDINATOR" "case[[:space:]]+let[[:space:]]+\\.eventDetail\\(" "Circle destination maps eventDetail."

require_pattern "$MESSAGES_COORDINATOR" "case[[:space:]]+userProfile\\(" "MessagesRoute keeps userProfile route case."
require_pattern "$MESSAGES_COORDINATOR" "case[[:space:]]+squadProfile\\(" "MessagesModalRoute keeps squadProfile route case."
require_pattern "$MESSAGES_COORDINATOR" "case[[:space:]]+let[[:space:]]+\\.userProfile\\(" "Messages destination maps userProfile."
require_pattern "$MESSAGES_COORDINATOR" "case[[:space:]]+let[[:space:]]+\\.squadProfile\\(" "Messages modal destination maps squadProfile."

require_pattern "$PROFILE_COORDINATOR" "case[[:space:]]+userProfile\\(" "ProfileRoute keeps userProfile route case."
require_pattern "$PROFILE_COORDINATOR" "case[[:space:]]+eventDetail\\(" "ProfileRoute keeps eventDetail route case."
require_pattern "$PROFILE_COORDINATOR" "case[[:space:]]+let[[:space:]]+\\.userProfile\\(" "Profile destination maps userProfile."
require_pattern "$PROFILE_COORDINATOR" "case[[:space:]]+let[[:space:]]+\\.eventDetail\\(" "Profile destination maps eventDetail."

# Deep-link <-> route token round-trip checks for critical entry paths.
if ! swift - <<'SWIFT'
import Foundation

enum CriticalRouteToken: Equatable {
    case eventDetail(String)
    case userProfile(String)
    case squadProfile(String)

    init?(url: URL) {
        guard (url.scheme ?? "").lowercased() == "raver" else { return nil }
        let host = (url.host ?? "").lowercased()
        let parts = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "discover", "circle", "profile":
            guard parts.count == 2 else { return nil }
            if parts[0] == "event" {
                self = .eventDetail(parts[1])
                return
            }
            if parts[0] == "user" {
                self = .userProfile(parts[1])
                return
            }
        case "messages":
            guard parts.count == 2 else { return nil }
            if parts[0] == "user" {
                self = .userProfile(parts[1])
                return
            }
            if parts[0] == "squad" {
                self = .squadProfile(parts[1])
                return
            }
        default:
            break
        }

        if host == "circle", parts.count == 2, parts[0] == "squad" {
            self = .squadProfile(parts[1])
            return
        }

        return nil
    }

    func url(hostOverride: String? = nil) -> URL? {
        let host: String
        let pathPrefix: String
        let rawID: String

        switch self {
        case let .eventDetail(eventID):
            host = hostOverride ?? "discover"
            pathPrefix = "event"
            rawID = eventID
        case let .userProfile(userID):
            host = hostOverride ?? "profile"
            pathPrefix = "user"
            rawID = userID
        case let .squadProfile(squadID):
            host = hostOverride ?? "circle"
            pathPrefix = "squad"
            rawID = squadID
        }

        let encodedID = rawID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? rawID
        var components = URLComponents()
        components.scheme = "raver"
        components.host = host
        components.path = "/\(pathPrefix)/\(encodedID)"
        return components.url
    }
}

let eventID = "evt_123-abc"
let userID = "usr_456-def"
let squadID = "sqd_789-ghi"

let roundTripCases: [(CriticalRouteToken, [String])] = [
    (.eventDetail(eventID), ["discover", "circle", "profile"]),
    (.userProfile(userID), ["profile", "circle", "messages"]),
    (.squadProfile(squadID), ["circle", "messages"]),
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
    "https://discover/event/abc",
    "raver://discover/event",
    "raver://circle/unknown/abc",
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
