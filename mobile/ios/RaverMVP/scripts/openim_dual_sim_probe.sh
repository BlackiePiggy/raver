#!/usr/bin/env bash
set -euo pipefail

SIM1_NAME="${1:-iPhone 17 Pro}"
SIM2_NAME="${2:-iPhone 17}"
BUNDLE_ID="${3:-com.raver.mvp}"
RAW_MODE="${OPENIM_PROBE_RAW_MODE:-0}"
LIVE_MODE="${OPENIM_PROBE_LIVE_MODE:-summary}"
BACKFILL_SECONDS="${OPENIM_PROBE_BACKFILL_SECONDS:-180}"
TRANSPORT_MODE="${OPENIM_PROBE_TRANSPORT:-stream}"
AUTO_STOP_SECONDS="${OPENIM_PROBE_AUTO_STOP_SECONDS:-0}"
ENSURE_OPENIM="${OPENIM_PROBE_ENSURE_OPENIM:-1}"
OPENIM_DOCKER_DIR="${OPENIM_DOCKER_DIR:-$HOME/Projects/vendor/openim-docker}"
OPENIM_WAIT_SECONDS="${OPENIM_PROBE_OPENIM_WAIT_SECONDS:-120}"
OPENIM_API_PORT="${OPENIM_PROBE_OPENIM_API_PORT:-10002}"
OPENIM_WS_PORT="${OPENIM_PROBE_OPENIM_WS_PORT:-10001}"
OPENIM_REQUIRE_HEALTH="${OPENIM_PROBE_REQUIRE_HEALTH:-1}"
OPENIM_HEALTH_TARGETS="${OPENIM_PROBE_HEALTH_TARGETS:-openim-server openim-chat}"
ENSURE_BFF="${OPENIM_PROBE_ENSURE_BFF:-1}"
BFF_PORT="${OPENIM_PROBE_BFF_PORT:-3901}"
USE_APP_PROBE_LOG="${OPENIM_PROBE_USE_APP_LOG:-1}"
APP_PROBE_REL_PATH="${OPENIM_PROBE_APP_LOG_REL_PATH:-Library/Caches/openim-probe.log}"
OPEN_SIM_WINDOWS="${OPENIM_PROBE_OPEN_SIM_WINDOWS:-0}"
SKIP_APP_RELAUNCH="${OPENIM_PROBE_SKIP_APP_RELAUNCH:-0}"
APP_CHILD_BASELINE_CHAT="${OPENIM_PROBE_BASELINE_CHAT:-0}"

ROOT_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
LOG_DIR="$ROOT_DIR/docs/reports"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$LOG_DIR/openim-dual-sim-$TIMESTAMP"
mkdir -p "$RUN_DIR"
RUN_START_EPOCH="$(date +%s)"

is_port_listening() {
  local port="$1"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
}

compose_file_in_dir() {
  local dir="$1"
  local candidate
  for candidate in docker-compose.yaml docker-compose.yml compose.yaml compose.yml; do
    if [[ -f "$dir/$candidate" ]]; then
      echo "$dir/$candidate"
      return
    fi
  done
}

openim_ports_ready() {
  is_port_listening "$OPENIM_WS_PORT" && is_port_listening "$OPENIM_API_PORT"
}

docker_container_running_status() {
  local container="$1"
  docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || true
}

docker_container_health_status() {
  local container="$1"
  docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$container" 2>/dev/null || true
}

openim_health_ready() {
  local container
  local running
  local health

  for container in $OPENIM_HEALTH_TARGETS; do
    running="$(docker_container_running_status "$container")"
    if [[ "$running" != "running" ]]; then
      return 1
    fi

    if [[ "$OPENIM_REQUIRE_HEALTH" == "1" ]]; then
      health="$(docker_container_health_status "$container")"
      if [[ "$health" != "healthy" && "$health" != "no-healthcheck" ]]; then
        return 1
      fi
    fi
  done

  return 0
}

start_openim_stack() {
  local compose_file

  if ! command -v docker >/dev/null 2>&1; then
    echo "OPENIM ensure failed: docker is not installed or not in PATH." >&2
    exit 1
  fi

  if ! docker info >/dev/null 2>&1; then
    echo "OPENIM ensure failed: docker daemon is not running." >&2
    exit 1
  fi

  if [[ ! -d "$OPENIM_DOCKER_DIR" ]]; then
    echo "OPENIM ensure failed: OPENIM_DOCKER_DIR does not exist: $OPENIM_DOCKER_DIR" >&2
    echo "Hint: export OPENIM_DOCKER_DIR=~/Projects/vendor/openim-docker" >&2
    exit 1
  fi

  compose_file="$(compose_file_in_dir "$OPENIM_DOCKER_DIR" || true)"
  echo "[probe] OpenIM not ready, starting docker stack..."
  if [[ -n "$compose_file" ]]; then
    docker compose -f "$compose_file" up -d >/dev/null
  else
    (cd "$OPENIM_DOCKER_DIR" && docker compose up -d >/dev/null)
  fi
}

print_openim_health_snapshot() {
  local container
  local running
  local health

  for container in $OPENIM_HEALTH_TARGETS; do
    running="$(docker_container_running_status "$container")"
    health="$(docker_container_health_status "$container")"
    echo "[probe] OpenIM status: $container running=$running health=$health"
  done
}

ensure_openim_ready() {
  local deadline
  local compose_file

  if openim_ports_ready && openim_health_ready; then
    echo "[probe] OpenIM ready: ws=$OPENIM_WS_PORT api=$OPENIM_API_PORT"
    if [[ "$OPENIM_REQUIRE_HEALTH" == "1" ]]; then
      print_openim_health_snapshot
    fi
    return
  fi

  if [[ "$ENSURE_OPENIM" != "1" ]]; then
    echo "OPENIM is not ready (ports=$OPENIM_WS_PORT/$OPENIM_API_PORT or health check failed)." >&2
    echo "Set OPENIM_PROBE_ENSURE_OPENIM=1 to auto-start OpenIM before probing." >&2
    exit 1
  fi

  start_openim_stack
  deadline=$((SECONDS + OPENIM_WAIT_SECONDS))
  while (( SECONDS < deadline )); do
    if openim_ports_ready && openim_health_ready; then
      echo "[probe] OpenIM started successfully: ws=$OPENIM_WS_PORT api=$OPENIM_API_PORT"
      if [[ "$OPENIM_REQUIRE_HEALTH" == "1" ]]; then
        print_openim_health_snapshot
      fi
      return
    fi

    if [[ "$OPENIM_REQUIRE_HEALTH" == "1" ]]; then
      print_openim_health_snapshot
    else
      echo "[probe] waiting OpenIM ports: ws=$OPENIM_WS_PORT api=$OPENIM_API_PORT"
    fi
    sleep 2
  done

  echo "OPENIM ensure failed: not ready after ${OPENIM_WAIT_SECONDS}s." >&2
  compose_file="$(compose_file_in_dir "$OPENIM_DOCKER_DIR" || true)"
  if [[ -n "$compose_file" ]]; then
    docker compose -f "$compose_file" ps || true
    docker compose -f "$compose_file" logs --tail=80 openim-server openim-chat || true
  elif [[ -d "$OPENIM_DOCKER_DIR" ]]; then
    (cd "$OPENIM_DOCKER_DIR" && docker compose ps) || true
    (cd "$OPENIM_DOCKER_DIR" && docker compose logs --tail=80 openim-server openim-chat) || true
  fi
  exit 1
}

ensure_bff_ready() {
  if is_port_listening "$BFF_PORT"; then
    echo "[probe] BFF ready: localhost:$BFF_PORT"
    return
  fi

  if [[ "$ENSURE_BFF" == "1" ]]; then
    echo "BFF ensure failed: localhost:$BFF_PORT is not listening." >&2
    echo "Start server first: cd /Users/blackie/Projects/raver/server && OPENIM_ENABLED=true pnpm dev" >&2
    echo "If your BFF is not localhost, set OPENIM_PROBE_ENSURE_BFF=0 for this probe run." >&2
    exit 1
  fi

  echo "[probe] warning: BFF localhost:$BFF_PORT not listening (OPENIM_PROBE_ENSURE_BFF=0)."
}

resolve_udid() {
  local name="$1"
  local udid
  udid="$(xcrun simctl list devices available | rg "^[[:space:]]*$name \\(" | head -n1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/' || true)"
  if [[ -z "$udid" ]]; then
    echo "Failed to resolve simulator UDID for '$name'" >&2
    exit 1
  fi
  echo "$udid"
}

boot_and_wait() {
  local udid="$1"
  local name="$2"
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  if ! xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1; then
    echo "Failed to boot simulator $name ($udid)" >&2
    xcrun simctl list devices | rg "$udid" || true
    exit 1
  fi
}

is_booted() {
  local udid="$1"
  xcrun simctl spawn "$udid" /usr/bin/true >/dev/null 2>&1
}

launch_with_retry() {
  local udid="$1"
  local name="$2"
  local attempts=5
  local i
  local output=""

  xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true

  for i in $(seq 1 "$attempts"); do
    if [[ "$APP_CHILD_BASELINE_CHAT" == "1" ]]; then
      if output="$(SIMCTL_CHILD_RAVER_OPENIM_BASELINE_CHAT=1 xcrun simctl launch "$udid" "$BUNDLE_ID" 2>&1)"; then
        echo "$output"
        return 0
      fi
    elif output="$(xcrun simctl launch "$udid" "$BUNDLE_ID" 2>&1)"; then
      echo "$output"
      return 0
    fi
    echo "Launch attempt $i/$attempts failed on $name ($udid): $output" >&2
    xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
    sleep 1
  done

  echo "Failed to launch $BUNDLE_ID on $name ($udid) after $attempts attempts" >&2
  echo "Last launch error: $output" >&2
  if ! xcrun simctl get_app_container "$udid" "$BUNDLE_ID" app >/dev/null 2>&1; then
    echo "App is not installed on $name ($udid). Build & run once on this simulator in Xcode first." >&2
  fi
  exit 1
}

ensure_booted_with_app() {
  local udid="$1"
  local name="$2"
  local attempts=3
  local i

  for i in $(seq 1 "$attempts"); do
    if is_booted "$udid"; then
      return 0
    fi
    echo "[probe] $name ($udid) is not booted, recovering ($i/$attempts)..." >&2
    boot_and_wait "$udid" "$name"
    launch_with_retry "$udid" "$name" >/dev/null 2>&1 || true
    sleep 1
  done

  echo "Failed to keep simulator booted: $name ($udid)" >&2
  exit 1
}

resolve_app_probe_log_path() {
  local udid="$1"
  local data_dir
  data_dir="$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" data 2>/dev/null || true)"
  if [[ -z "$data_dir" ]]; then
    echo ""
    return
  fi
  echo "$data_dir/$APP_PROBE_REL_PATH"
}

prepare_app_probe_log() {
  local label="$1"
  local app_log="$2"
  local err_file="$3"

  if [[ "$USE_APP_PROBE_LOG" != "1" ]]; then
    return
  fi
  if [[ -z "$app_log" ]]; then
    echo "[$label] app probe log unavailable: app container not found" >>"$err_file"
    return
  fi

  mkdir -p "$(dirname "$app_log")"
  : >"$app_log"
}

merge_app_probe_log() {
  local label="$1"
  local app_log="$2"
  local raw_file="$3"
  local focus_file="$4"
  local err_file="$5"

  if [[ "$USE_APP_PROBE_LOG" != "1" ]]; then
    return
  fi
  if [[ -z "$app_log" || ! -f "$app_log" ]]; then
    return
  fi
  if [[ ! -s "$app_log" ]]; then
    echo "[$label] app probe log is empty: $app_log" >>"$err_file"
    return
  fi

  sed "s/^/[$label][app-probe] /" "$app_log" >>"$raw_file"
  if [[ "$RAW_MODE" != "1" ]]; then
    rg -i "$FOCUS_REGEX" "$raw_file" >"$focus_file" 2>/dev/null || true
  fi
}

ensure_openim_ready
ensure_bff_ready

SIM1_UDID="$(resolve_udid "$SIM1_NAME")"
SIM2_UDID="$(resolve_udid "$SIM2_NAME")"

echo "SIM1: $SIM1_NAME ($SIM1_UDID)"
echo "SIM2: $SIM2_NAME ($SIM2_UDID)"
echo "Bundle: $BUNDLE_ID"
echo "Log dir: $RUN_DIR"
echo "Skip relaunch: $SKIP_APP_RELAUNCH"
echo "Baseline chat env: $APP_CHILD_BASELINE_CHAT"

boot_and_wait "$SIM1_UDID" "$SIM1_NAME"
boot_and_wait "$SIM2_UDID" "$SIM2_NAME"

if [[ "$OPEN_SIM_WINDOWS" == "1" ]]; then
  # Optional UI mode: open Simulator app focused to each device.
  open -a Simulator --args -CurrentDeviceUDID "$SIM1_UDID" >/dev/null 2>&1 || true
  sleep 1
  open -a Simulator --args -CurrentDeviceUDID "$SIM2_UDID" >/dev/null 2>&1 || true
fi

if [[ "$SKIP_APP_RELAUNCH" == "1" ]]; then
  echo "SIM1 launch: skipped (OPENIM_PROBE_SKIP_APP_RELAUNCH=1)"
  echo "SIM2 launch: skipped (OPENIM_PROBE_SKIP_APP_RELAUNCH=1)"
else
  SIM1_LAUNCH_OUTPUT="$(launch_with_retry "$SIM1_UDID" "$SIM1_NAME")"
  SIM2_LAUNCH_OUTPUT="$(launch_with_retry "$SIM2_UDID" "$SIM2_NAME")"
  echo "SIM1 launch: $SIM1_LAUNCH_OUTPUT"
  echo "SIM2 launch: $SIM2_LAUNCH_OUTPUT"
fi
ensure_booted_with_app "$SIM1_UDID" "$SIM1_NAME"
ensure_booted_with_app "$SIM2_UDID" "$SIM2_NAME"

LOG1="$RUN_DIR/sim1.log"
LOG2="$RUN_DIR/sim2.log"
FOCUS1="$RUN_DIR/sim1.focus.log"
FOCUS2="$RUN_DIR/sim2.focus.log"
ERR1="$RUN_DIR/sim1.err.log"
ERR2="$RUN_DIR/sim2.err.log"
APP_LOG1=""
APP_LOG2=""

BASE_PREDICATE='process == "RaverMVP" AND (subsystem == "com.raver.mvp" OR eventMessage CONTAINS "[OpenIM" OR eventMessage CONTAINS "[AppState]")'
FOCUS_REGEX='\[OpenIMSession\]|\[OpenIMChatStore\]|\[AppState\]|\[ConversationLoader\]|\[OpenIMDemoBaselineUpdate\]|\[OpenIMDemoBaselineRoute\]|\[DemoAlignedChat\]|\[DemoAlignedPagination\]|\[DemoAlignedViewport\]|\[DemoAlignedScroll\]|\[DemoAlignedMessageFlow\]|\[GlobalSearch\]|\[DemoAlignedSearch\]|10102|logged in repeatedly|OpenIM state ->|realtime message received|badge recompute source=openim-realtime|badge recompute source=community-event|catchup messages changed|catchup conversations changed|OpenIM .* unavailable|fallback to BFF'
DIGEST_SCRIPT="$ROOT_DIR/mobile/ios/RaverMVP/scripts/openim_probe_digest.sh"

touch "$LOG1" "$LOG2" "$FOCUS1" "$FOCUS2" "$ERR1" "$ERR2"

APP_LOG1="$(resolve_app_probe_log_path "$SIM1_UDID")"
APP_LOG2="$(resolve_app_probe_log_path "$SIM2_UDID")"
prepare_app_probe_log "SIM1" "$APP_LOG1" "$ERR1"
prepare_app_probe_log "SIM2" "$APP_LOG2" "$ERR2"

app_running_on_sim() {
  local udid="$1"
  xcrun simctl spawn "$udid" launchctl list 2>/dev/null | rg -q "UIKitApplication:$BUNDLE_ID"
}

seed_recent_logs() {
  local udid="$1"
  local label="$2"
  local raw_file="$3"
  local err_file="$4"

  xcrun simctl spawn "$udid" log show --style compact --last 20s \
    --predicate "$BASE_PREDICATE" 2>>"$err_file" \
    | sed "s/^/[$label] /" >>"$raw_file" || true
}

collect_snapshot_logs() {
  local udid="$1"
  local label="$2"
  local name="$3"
  local raw_file="$4"
  local err_file="$5"
  local window_seconds="$6"

  ensure_booted_with_app "$udid" "$name"
  echo "[$label] snapshot collect: log show --last ${window_seconds}s" >&2
  xcrun simctl spawn "$udid" log show --style compact --last "${window_seconds}s" \
    --predicate "$BASE_PREDICATE" 2>>"$err_file" \
    | sed "s/^/[$label] /" >"$raw_file" || true
}

stream_for_sim() {
  local udid="$1"
  local label="$2"
  local raw_file="$3"
  local focus_file="$4"
  local err_file="$5"
  local pid_raw=""
  local pid_focus=""

  if [[ "$RAW_MODE" == "1" ]]; then
    if [[ "$LIVE_MODE" == "stream" ]]; then
      (
        xcrun simctl spawn "$udid" log stream --style compact --level debug \
          --predicate "$BASE_PREDICATE" 2>>"$err_file" \
          | sed "s/^/[$label] /" | tee "$raw_file"
      ) &
      pid_raw="$!"
    else
      (
        xcrun simctl spawn "$udid" log stream --style compact --level debug \
          --predicate "$BASE_PREDICATE" 2>>"$err_file" \
          | sed "s/^/[$label] /" | tee "$raw_file" >/dev/null
      ) &
      pid_raw="$!"
    fi
  else
    if [[ "$LIVE_MODE" == "stream" ]]; then
      (
        xcrun simctl spawn "$udid" log stream --style compact --level debug \
          --predicate "$BASE_PREDICATE" 2>>"$err_file" \
          | sed "s/^/[$label] /" | tee "$raw_file" \
          | rg --line-buffered -i "$FOCUS_REGEX" | tee "$focus_file"
      ) &
      pid_raw="$!"
    else
      (
        xcrun simctl spawn "$udid" log stream --style compact --level debug \
          --predicate "$BASE_PREDICATE" 2>>"$err_file" \
          | sed "s/^/[$label] /" | tee "$raw_file" >/dev/null
      ) &
      pid_raw="$!"
      (
        tail -n 0 -F "$raw_file" | rg --line-buffered -i "$FOCUS_REGEX" | tee "$focus_file" >/dev/null
      ) &
      pid_focus="$!"
    fi
  fi
  echo "$pid_raw $pid_focus"
}

count_or_zero() {
  local pattern="$1"
  local file="$2"
  rg -ci "$pattern" "$file" 2>/dev/null || echo 0
}

print_summary() {
  local sim_label
  local source_file
  local c_connected
  local c_unavailable
  local c_10102
  local c_realtime
  local c_catchup
  local c_fallback

  echo
  echo "===== OpenIM Probe Summary ====="
  echo "Log dir: $RUN_DIR"
  echo

  for sim_label in 1 2; do
    if [[ "$sim_label" == "1" ]]; then
      source_file="$LOG1"
      if [[ "$RAW_MODE" != "1" && -s "$FOCUS1" ]]; then
        source_file="$FOCUS1"
      fi
      err_file="$ERR1"
    else
      source_file="$LOG2"
      if [[ "$RAW_MODE" != "1" && -s "$FOCUS2" ]]; then
        source_file="$FOCUS2"
      fi
      err_file="$ERR2"
    fi

    if [[ ! -f "$source_file" ]]; then
      continue
    fi

    c_connected="$(count_or_zero 'state -> connected' "$source_file")"
    c_unavailable="$(count_or_zero 'state -> unavailable|OpenIM .* unavailable' "$source_file")"
    c_10102="$(count_or_zero '10102|logged in repeatedly' "$source_file")"
    c_realtime="$(count_or_zero 'realtime message received|onRecvNewMessage|badge recompute source=openim-realtime' "$source_file")"
    c_catchup="$(count_or_zero 'catchup messages changed|catchup conversations changed' "$source_file")"
    c_fallback="$(count_or_zero 'fallback to BFF' "$source_file")"

    echo "SIM$sim_label: connected=$c_connected unavailable=$c_unavailable login10102=$c_10102 realtime=$c_realtime catchup=$c_catchup fallback=$c_fallback"
    if [[ ! -s "$source_file" ]]; then
      echo "SIM$sim_label warning: no captured log lines in $source_file"
      echo "SIM$sim_label app-running-check:"
      if [[ "$sim_label" == "1" ]]; then
        if app_running_on_sim "$SIM1_UDID"; then
          echo "  running=yes"
        else
          echo "  running=no"
        fi
      else
        if app_running_on_sim "$SIM2_UDID"; then
          echo "  running=yes"
        else
          echo "  running=no"
        fi
      fi
      if [[ -s "$err_file" ]]; then
        echo "SIM$sim_label stderr tail:"
        tail -n 20 "$err_file"
      fi
    fi
    echo "SIM$sim_label key tail:"
    rg -i "$FOCUS_REGEX" "$source_file" 2>/dev/null | tail -n 12 || true
    echo
  done

  if [[ -x "$DIGEST_SCRIPT" ]]; then
    echo "Digest report:"
    "$DIGEST_SCRIPT" "$RUN_DIR" || true
    echo
  fi
}

backfill_if_empty() {
  local udid="$1"
  local label="$2"
  local name="$3"
  local raw_file="$4"
  local focus_file="$5"
  local err_file="$6"

  if [[ -s "$raw_file" ]]; then
    return
  fi

  echo "[$label] backfill start: log show --last ${BACKFILL_SECONDS}s" >&2
  ensure_booted_with_app "$udid" "$name"
  xcrun simctl spawn "$udid" log show --style compact --last "${BACKFILL_SECONDS}s" \
    --predicate "$BASE_PREDICATE" 2>>"$err_file" \
    | sed "s/^/[$label] /" >>"$raw_file" || true

  if [[ "$RAW_MODE" != "1" ]]; then
    rg -i "$FOCUS_REGEX" "$raw_file" >"$focus_file" 2>/dev/null || true
  fi
}

print_live_snapshot() {
  local s1_file="$FOCUS1"
  local s2_file="$FOCUS2"
  local s1_connected s1_10102 s1_rt s1_catchup s1_unavailable
  local s2_connected s2_10102 s2_rt s2_catchup s2_unavailable

  if [[ "$RAW_MODE" == "1" ]]; then
    s1_file="$LOG1"
    s2_file="$LOG2"
  fi

  s1_connected="$(count_or_zero 'state -> connected' "$s1_file")"
  s1_10102="$(count_or_zero '10102|logged in repeatedly' "$s1_file")"
  s1_rt="$(count_or_zero 'realtime message received|badge recompute source=openim-realtime' "$s1_file")"
  s1_catchup="$(count_or_zero 'catchup messages changed|catchup conversations changed' "$s1_file")"
  s1_unavailable="$(count_or_zero 'OpenIM .* unavailable|state -> unavailable' "$s1_file")"

  s2_connected="$(count_or_zero 'state -> connected' "$s2_file")"
  s2_10102="$(count_or_zero '10102|logged in repeatedly' "$s2_file")"
  s2_rt="$(count_or_zero 'realtime message received|badge recompute source=openim-realtime' "$s2_file")"
  s2_catchup="$(count_or_zero 'catchup messages changed|catchup conversations changed' "$s2_file")"
  s2_unavailable="$(count_or_zero 'OpenIM .* unavailable|state -> unavailable' "$s2_file")"

  echo "[$(date +%H:%M:%S)] S1 conn=$s1_connected rt=$s1_rt catchup=$s1_catchup 10102=$s1_10102 unavail=$s1_unavailable | S2 conn=$s2_connected rt=$s2_rt catchup=$s2_catchup 10102=$s2_10102 unavail=$s2_unavailable"
}

live_summary_loop() {
  while true; do
    print_live_snapshot
    sleep 5
  done
}

cleanup() {
  if [[ -n "${PID1:-}" ]]; then kill "$PID1" >/dev/null 2>&1 || true; fi
  if [[ -n "${PID2:-}" ]]; then kill "$PID2" >/dev/null 2>&1 || true; fi
  if [[ -n "${PID1_FOCUS:-}" ]]; then kill "$PID1_FOCUS" >/dev/null 2>&1 || true; fi
  if [[ -n "${PID2_FOCUS:-}" ]]; then kill "$PID2_FOCUS" >/dev/null 2>&1 || true; fi
  if [[ -n "${SUMMARY_PID:-}" ]]; then kill "$SUMMARY_PID" >/dev/null 2>&1 || true; fi
  if [[ -n "${AUTO_STOP_PID:-}" ]]; then kill "$AUTO_STOP_PID" >/dev/null 2>&1 || true; fi
}

on_exit() {
  if [[ "${_PROBE_EXIT_DONE:-0}" == "1" ]]; then
    return
  fi
  _PROBE_EXIT_DONE=1
  cleanup
  if [[ "$TRANSPORT_MODE" == "snapshot" ]]; then
    local now_epoch snapshot_window
    now_epoch="$(date +%s)"
    snapshot_window=$(( now_epoch - RUN_START_EPOCH + 8 ))
    if [[ "$snapshot_window" -lt 20 ]]; then
      snapshot_window=20
    fi
    collect_snapshot_logs "$SIM1_UDID" "SIM1" "$SIM1_NAME" "$LOG1" "$ERR1" "$snapshot_window"
    collect_snapshot_logs "$SIM2_UDID" "SIM2" "$SIM2_NAME" "$LOG2" "$ERR2" "$snapshot_window"
    if [[ "$RAW_MODE" != "1" ]]; then
      rg -i "$FOCUS_REGEX" "$LOG1" >"$FOCUS1" 2>/dev/null || true
      rg -i "$FOCUS_REGEX" "$LOG2" >"$FOCUS2" 2>/dev/null || true
    fi
  fi
  merge_app_probe_log "SIM1" "$APP_LOG1" "$LOG1" "$FOCUS1" "$ERR1"
  merge_app_probe_log "SIM2" "$APP_LOG2" "$LOG2" "$FOCUS2" "$ERR2"
  backfill_if_empty "$SIM1_UDID" "SIM1" "$SIM1_NAME" "$LOG1" "$FOCUS1" "$ERR1"
  backfill_if_empty "$SIM2_UDID" "SIM2" "$SIM2_NAME" "$LOG2" "$FOCUS2" "$ERR2"
  print_summary
}

on_interrupt() {
  on_exit
  exit 130
}

trap on_exit EXIT
trap on_interrupt INT TERM QUIT

echo
echo "Starting log probes..."
echo "  SIM1 -> $LOG1"
echo "  SIM2 -> $LOG2"
if [[ "$RAW_MODE" != "1" ]]; then
  echo "  SIM1 focus -> $FOCUS1"
  echo "  SIM2 focus -> $FOCUS2"
fi
echo "  SIM1 err -> $ERR1"
echo "  SIM2 err -> $ERR2"
if [[ "$USE_APP_PROBE_LOG" == "1" ]]; then
  if [[ -n "$APP_LOG1" ]]; then
    echo "  SIM1 app-probe -> $APP_LOG1"
  else
    echo "  SIM1 app-probe -> unavailable"
  fi
  if [[ -n "$APP_LOG2" ]]; then
    echo "  SIM2 app-probe -> $APP_LOG2"
  else
    echo "  SIM2 app-probe -> unavailable"
  fi
fi
echo "  live mode -> $LIVE_MODE"
echo "  transport -> $TRANSPORT_MODE"
echo

if [[ "$TRANSPORT_MODE" == "stream" ]]; then
  if [[ "$RAW_MODE" == "1" || "$LIVE_MODE" == "stream" ]]; then
    seed_recent_logs "$SIM1_UDID" "SIM1" "$LOG1" "$ERR1"
    seed_recent_logs "$SIM2_UDID" "SIM2" "$LOG2" "$ERR2"
    read -r PID1 PID1_FOCUS <<<"$(stream_for_sim "$SIM1_UDID" "SIM1" "$LOG1" "$FOCUS1" "$ERR1")"
    read -r PID2 PID2_FOCUS <<<"$(stream_for_sim "$SIM2_UDID" "SIM2" "$LOG2" "$FOCUS2" "$ERR2")"
  else
    # In summary mode we run 2 workers per simulator: raw collector + focus extractor.
    seed_recent_logs "$SIM1_UDID" "SIM1" "$LOG1" "$ERR1"
    seed_recent_logs "$SIM2_UDID" "SIM2" "$LOG2" "$ERR2"
    read -r PID1 PID1_FOCUS <<<"$(stream_for_sim "$SIM1_UDID" "SIM1" "$LOG1" "$FOCUS1" "$ERR1")"
    read -r PID2 PID2_FOCUS <<<"$(stream_for_sim "$SIM2_UDID" "SIM2" "$LOG2" "$FOCUS2" "$ERR2")"
  fi

  sleep 1
  if ! kill -0 "$PID1" >/dev/null 2>&1; then
    echo "SIM1 log probe exited unexpectedly. Check log stream permissions on host." >&2
    exit 1
  fi
  if ! kill -0 "$PID2" >/dev/null 2>&1; then
    echo "SIM2 log probe exited unexpectedly. Check log stream permissions on host." >&2
    exit 1
  fi

  sleep 2
  if [[ ! -s "$LOG1" ]]; then
    echo "SIM1 warning: no raw logs captured yet. See $ERR1" >&2
  fi
  if [[ ! -s "$LOG2" ]]; then
    echo "SIM2 warning: no raw logs captured yet. See $ERR2" >&2
  fi
fi

echo "Probe is running. Press Ctrl+C to stop."
echo
if [[ "$LIVE_MODE" == "summary" ]]; then
  if [[ "$TRANSPORT_MODE" == "snapshot" ]]; then
    echo "Live summary enabled (snapshot transport)."
    echo "Note: counters stay 0 before stop; snapshot logs are collected only on Ctrl+C/exit."
  else
    echo "Live summary enabled. A compact status line will print every 5s."
  fi
  echo
  live_summary_loop &
  SUMMARY_PID="$!"
else
  echo "Quick checks:"
  if [[ "$RAW_MODE" == "1" ]]; then
    echo "  rg -i \"10102|logged in repeatedly|state ->|fallback|realtime|catchup\" \"$LOG1\" \"$LOG2\""
  else
    echo "  rg -i \"10102|logged in repeatedly|state ->|fallback|realtime|catchup\" \"$FOCUS1\" \"$FOCUS2\""
  fi
fi
echo
echo "Tips:"
echo "  OPENIM_PROBE_LIVE_MODE=summary  # low-noise counters (default)"
echo "  OPENIM_PROBE_LIVE_MODE=stream   # print matched focus lines"
echo "  OPENIM_PROBE_RAW_MODE=1         # print full raw logs"
echo "  OPENIM_PROBE_BACKFILL_SECONDS=180 # backfill window when a side is empty"
echo "  OPENIM_PROBE_TRANSPORT=snapshot # collect logs once on exit (more stable)"
echo "  OPENIM_PROBE_AUTO_STOP_SECONDS=90 # auto-stop probe after N seconds"
echo "  OPENIM_PROBE_ENSURE_OPENIM=1 # auto-start and verify OpenIM before probing"
echo "  OPENIM_DOCKER_DIR=~/Projects/vendor/openim-docker # OpenIM docker directory"
echo "  OPENIM_PROBE_REQUIRE_HEALTH=1 # require openim-server/openim-chat health=healthy"
echo "  OPENIM_PROBE_ENSURE_BFF=1 # require localhost BFF port before probing"
echo "  OPENIM_PROBE_USE_APP_LOG=1 # merge in-app probe file log on exit"
echo "  OPENIM_PROBE_OPEN_SIM_WINDOWS=1 # optional: open Simulator UI windows"

if [[ "$AUTO_STOP_SECONDS" =~ ^[0-9]+$ ]] && [[ "$AUTO_STOP_SECONDS" -gt 0 ]]; then
  (
    sleep "$AUTO_STOP_SECONDS"
    echo
    echo "[probe] auto-stop after ${AUTO_STOP_SECONDS}s"
    kill -s INT "$$" >/dev/null 2>&1 || true
  ) &
  AUTO_STOP_PID="$!"
fi

wait
