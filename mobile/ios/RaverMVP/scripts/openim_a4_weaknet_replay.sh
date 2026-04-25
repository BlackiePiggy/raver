#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
PROBE_SCRIPT="$ROOT_DIR/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh"
DIGEST_SCRIPT="$ROOT_DIR/mobile/ios/RaverMVP/scripts/openim_probe_digest.sh"
SERVER_DIR="$ROOT_DIR/server"

SIM1_NAME="${1:-iPhone 17 Pro}"
SIM2_NAME="${2:-iPhone 17}"
BUNDLE_ID="${3:-com.raver.mvp}"

OPENIM_DOCKER_DIR="${OPENIM_DOCKER_DIR:-$HOME/Projects/vendor/openim-docker}"
OPENIM_PROBE_SENDER_IDENTIFIER="${OPENIM_PROBE_SENDER_IDENTIFIER:-blackie}"
OPENIM_PROBE_RECEIVER_IDENTIFIER="${OPENIM_PROBE_RECEIVER_IDENTIFIER:-uploadtester}"
OPENIM_PROBE_SESSION_TYPE="${OPENIM_PROBE_SESSION_TYPE:-single}"
OPENIM_PROBE_GROUP_ID="${OPENIM_PROBE_GROUP_ID:-}"
OPENIM_PROBE_INTERVAL_MS="${OPENIM_PROBE_INTERVAL_MS:-600}"
OPENIM_PROBE_PRE_OUTAGE_COUNT="${OPENIM_PROBE_PRE_OUTAGE_COUNT:-2}"
OPENIM_PROBE_DURING_OUTAGE_COUNT="${OPENIM_PROBE_DURING_OUTAGE_COUNT:-1}"
OPENIM_PROBE_POST_RECOVERY_COUNT="${OPENIM_PROBE_POST_RECOVERY_COUNT:-3}"
OPENIM_PROBE_WARMUP_DELAY_SECONDS="${OPENIM_PROBE_WARMUP_DELAY_SECONDS:-12}"
OPENIM_PROBE_OUTAGE_SECONDS="${OPENIM_PROBE_OUTAGE_SECONDS:-15}"
OPENIM_PROBE_RECOVERY_STABILIZE_SECONDS="${OPENIM_PROBE_RECOVERY_STABILIZE_SECONDS:-8}"
OPENIM_PROBE_MESSAGE_PREFIX="${OPENIM_PROBE_MESSAGE_PREFIX:-[a4-weaknet]}"
OPENIM_PROBE_WAIT_TIMEOUT_SECONDS="${OPENIM_PROBE_WAIT_TIMEOUT_SECONDS:-900}"
OPENIM_PROBE_REPLAY_TRANSPORT="${OPENIM_PROBE_REPLAY_TRANSPORT:-snapshot}"
OPENIM_PROBE_POST_RECOVERY_CAPTURE_SECONDS="${OPENIM_PROBE_POST_RECOVERY_CAPTURE_SECONDS:-25}"

COMPOSE_FILE=""
PROBE_CAPTURE=""
PROBE_PID=""
RUN_DIR=""

log() {
  echo "[a4-weaknet] $*"
}

resolve_compose_file() {
  local candidate
  for candidate in docker-compose.yaml docker-compose.yml compose.yaml compose.yml; do
    if [[ -f "$OPENIM_DOCKER_DIR/$candidate" ]]; then
      COMPOSE_FILE="$OPENIM_DOCKER_DIR/$candidate"
      return 0
    fi
  done
  return 1
}

compose_cmd() {
  if [[ -n "$COMPOSE_FILE" ]]; then
    docker compose -f "$COMPOSE_FILE" "$@"
  else
    (cd "$OPENIM_DOCKER_DIR" && docker compose "$@")
  fi
}

send_probe_messages() {
  local phase="$1"
  local count="$2"
  local allow_fail="${3:-0}"
  if [[ "$count" -le 0 ]]; then
    return 0
  fi

  log "inject phase=$phase count=$count session=$OPENIM_PROBE_SESSION_TYPE"
  set +e
  (
    cd "$SERVER_DIR"
    OPENIM_PROBE_SESSION_TYPE="$OPENIM_PROBE_SESSION_TYPE" \
    OPENIM_PROBE_SENDER_IDENTIFIER="$OPENIM_PROBE_SENDER_IDENTIFIER" \
    OPENIM_PROBE_RECEIVER_IDENTIFIER="$OPENIM_PROBE_RECEIVER_IDENTIFIER" \
    OPENIM_PROBE_GROUP_ID="$OPENIM_PROBE_GROUP_ID" \
    OPENIM_PROBE_MESSAGE_COUNT="$count" \
    OPENIM_PROBE_INTERVAL_MS="$OPENIM_PROBE_INTERVAL_MS" \
    OPENIM_PROBE_MESSAGE_PREFIX="$OPENIM_PROBE_MESSAGE_PREFIX $phase" \
    npm run openim:probe:send
  )
  local exit_code=$?
  set -e

  if [[ "$exit_code" -ne 0 ]]; then
    if [[ "$allow_fail" == "1" ]]; then
      log "inject phase=$phase expected failure exit=$exit_code"
    else
      log "inject phase=$phase failed exit=$exit_code"
      return "$exit_code"
    fi
  fi
  return 0
}

cleanup() {
  set +e
  if [[ -n "$PROBE_PID" ]]; then
    if kill -0 "$PROBE_PID" >/dev/null 2>&1; then
      log "cleanup: terminating probe pid=$PROBE_PID"
      kill -TERM "-$PROBE_PID" >/dev/null 2>&1 || kill -TERM "$PROBE_PID" >/dev/null 2>&1 || true
      sleep 2
      kill -KILL "-$PROBE_PID" >/dev/null 2>&1 || kill -KILL "$PROBE_PID" >/dev/null 2>&1 || true
    fi
  fi
  compose_cmd start openim-server openim-chat >/dev/null 2>&1 || true
  set -e
}

trap cleanup EXIT

if [[ ! -x "$PROBE_SCRIPT" ]]; then
  echo "probe script not executable: $PROBE_SCRIPT" >&2
  exit 1
fi
if [[ ! -x "$DIGEST_SCRIPT" ]]; then
  echo "digest script not executable: $DIGEST_SCRIPT" >&2
  exit 1
fi
if [[ ! -d "$SERVER_DIR" ]]; then
  echo "server dir not found: $SERVER_DIR" >&2
  exit 1
fi
if [[ ! -d "$OPENIM_DOCKER_DIR" ]]; then
  echo "openim docker dir not found: $OPENIM_DOCKER_DIR" >&2
  exit 1
fi

resolve_compose_file || true
if [[ -n "$COMPOSE_FILE" ]]; then
  log "using compose file: $COMPOSE_FILE"
else
  log "using compose file from directory: $OPENIM_DOCKER_DIR"
fi

PROBE_CAPTURE="$(mktemp -t openim-a4-weaknet-probe.XXXXXX.log)"
log "probe capture: $PROBE_CAPTURE"

if command -v setsid >/dev/null 2>&1; then
  OPENIM_PROBE_USE_APP_LOG=1 \
  OPENIM_PROBE_TRANSPORT="$OPENIM_PROBE_REPLAY_TRANSPORT" \
  setsid bash "$PROBE_SCRIPT" "$SIM1_NAME" "$SIM2_NAME" "$BUNDLE_ID" >"$PROBE_CAPTURE" 2>&1 &
else
  OPENIM_PROBE_USE_APP_LOG=1 \
  OPENIM_PROBE_TRANSPORT="$OPENIM_PROBE_REPLAY_TRANSPORT" \
  bash "$PROBE_SCRIPT" "$SIM1_NAME" "$SIM2_NAME" "$BUNDLE_ID" >"$PROBE_CAPTURE" 2>&1 &
fi
PROBE_PID="$!"
log "probe started pid=$PROBE_PID transport=$OPENIM_PROBE_REPLAY_TRANSPORT"

sleep "$OPENIM_PROBE_WARMUP_DELAY_SECONDS"
send_probe_messages "pre-outage" "$OPENIM_PROBE_PRE_OUTAGE_COUNT" 0

log "stopping OpenIM for ${OPENIM_PROBE_OUTAGE_SECONDS}s"
compose_cmd stop openim-chat openim-server >/dev/null
send_probe_messages "during-outage" "$OPENIM_PROBE_DURING_OUTAGE_COUNT" 1
sleep "$OPENIM_PROBE_OUTAGE_SECONDS"

log "starting OpenIM"
compose_cmd start openim-server openim-chat >/dev/null
sleep "$OPENIM_PROBE_RECOVERY_STABILIZE_SECONDS"
send_probe_messages "post-recovery" "$OPENIM_PROBE_POST_RECOVERY_COUNT" 0

log "capture post-recovery window ${OPENIM_PROBE_POST_RECOVERY_CAPTURE_SECONDS}s"
sleep "$OPENIM_PROBE_POST_RECOVERY_CAPTURE_SECONDS"

log "stopping probe pid=$PROBE_PID with INT"
kill -INT "-$PROBE_PID" >/dev/null 2>&1 || kill -INT "$PROBE_PID" >/dev/null 2>&1 || true

log "waiting probe completion"
deadline=$((SECONDS + OPENIM_PROBE_WAIT_TIMEOUT_SECONDS))
while kill -0 "$PROBE_PID" >/dev/null 2>&1; do
  if (( SECONDS >= deadline )); then
    log "probe timeout after ${OPENIM_PROBE_WAIT_TIMEOUT_SECONDS}s, terminating pid=$PROBE_PID"
    kill -TERM "-$PROBE_PID" >/dev/null 2>&1 || kill -TERM "$PROBE_PID" >/dev/null 2>&1 || true
    sleep 2
    kill -KILL "-$PROBE_PID" >/dev/null 2>&1 || kill -KILL "$PROBE_PID" >/dev/null 2>&1 || true
    break
  fi
  sleep 2
done
wait "$PROBE_PID" 2>/dev/null || true
PROBE_PID=""

RUN_DIR="$(rg -o 'Log dir: .*' "$PROBE_CAPTURE" | tail -n1 | sed -E 's/^Log dir: //')"
if [[ -z "$RUN_DIR" || ! -d "$RUN_DIR" ]]; then
  echo "cannot resolve run dir from probe capture: $PROBE_CAPTURE" >&2
  tail -n 80 "$PROBE_CAPTURE" >&2 || true
  exit 1
fi

log "run dir: $RUN_DIR"
bash "$DIGEST_SCRIPT" "$RUN_DIR"

log "failure-chain quick check"
rg -n "send failure hint shown|send .* failed|resend failed|OpenIM .* unavailable|10102|logged in repeatedly" \
  "$RUN_DIR"/sim1.log "$RUN_DIR"/sim2.log "$RUN_DIR"/sim1.focus.log "$RUN_DIR"/sim2.focus.log 2>/dev/null || true

log "done"
