#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_NAME="${1:-ios-mixed}"
SCRIPT="$ROOT_DIR/load-tests/${TEST_NAME}.js"
RESULT_DIR="$ROOT_DIR/load-tests/results"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

if [[ ! -f "$SCRIPT" ]]; then
  echo "Unknown load test: $TEST_NAME" >&2
  echo "Available tests:" >&2
  find "$ROOT_DIR/load-tests" -maxdepth 1 -name '*.js' -print | sed 's#.*/##; s#\.js$##' >&2
  exit 1
fi

mkdir -p "$RESULT_DIR"

export K6_SUMMARY_JSON="$RESULT_DIR/${TEST_NAME}_${TIMESTAMP}_summary.json"
export K6_SUMMARY_MD="$RESULT_DIR/${TEST_NAME}_${TIMESTAMP}_summary.md"

K6_ARGS=()
if [[ -n "${K6_PROXY:-}" ]]; then
  K6_ARGS+=(--address "$K6_PROXY")
fi

echo "Running k6 test: $TEST_NAME"
echo "BASE_URL=${BASE_URL:-http://127.0.0.1:3901}"
echo "PROFILE=${PROFILE:-baseline}"
echo "Summary JSON: $K6_SUMMARY_JSON"
echo "Summary MD:   $K6_SUMMARY_MD"

k6 run \
  --summary-trend-stats "avg,min,med,p(90),p(95),p(99),max" \
  --out "json=$RESULT_DIR/${TEST_NAME}_${TIMESTAMP}_samples.json" \
  ${K6_ARGS+"${K6_ARGS[@]}"} \
  "$SCRIPT"
