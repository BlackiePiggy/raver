#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

"$ROOT_DIR/scripts/check-mvvm-coordinator-boundaries.sh"
"$ROOT_DIR/scripts/check-coordinator-routing-regression.sh"
"$ROOT_DIR/scripts/check-coordinator-deeplink-roundtrip.sh"
"$ROOT_DIR/scripts/check-coordinator-route-snapshots.sh"

echo "Coordinator hardening preflight passed."
