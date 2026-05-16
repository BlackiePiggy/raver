#!/usr/bin/env bash

set -euo pipefail

PROJECT_NAME="${PROJECT_NAME:-RaverMVP}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$REPO_ROOT/mobile/ios/RaverMVP}"
DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-$HOME/Library/Developer/Xcode/DerivedData}"
SIGNAL="${SIGNAL:-TERM}"
FORCE="${FORCE:-0}"
INCLUDE_INDEX="${INCLUDE_INDEX:-0}"

say() {
  printf '\033[1;34m[kill-xcode-build-locks]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[kill-xcode-build-locks]\033[0m %s\n' "$*" >&2
}

usage() {
  cat <<'EOF'
Usage:
  scripts/kill-xcode-build-locks.sh

Options via environment variables:
  PROJECT_NAME=RaverMVP       DerivedData project prefix to target.
  PROJECT_PATH=...            Project path hint used to find related build processes.
  DERIVED_DATA_ROOT=...       Override Xcode DerivedData root.
  FORCE=1                     Send SIGKILL after SIGTERM if processes remain.
  INCLUDE_INDEX=1             Also kill SourceKit/SKAgent index/typecheck work for this project.

Examples:
  scripts/kill-xcode-build-locks.sh
  FORCE=1 scripts/kill-xcode-build-locks.sh
  INCLUDE_INDEX=1 FORCE=1 scripts/kill-xcode-build-locks.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v lsof >/dev/null 2>&1; then
  warn "lsof is not available; cannot inspect build.db lockers."
  exit 1
fi

if [[ ! -d "$DERIVED_DATA_ROOT" ]]; then
  say "DerivedData root does not exist: $DERIVED_DATA_ROOT"
  exit 0
fi

declare -a PIDS=()
declare -a TARGET_DIRS=()

add_pid() {
  local pid="$1"
  [[ -z "$pid" ]] && return 0
  [[ "$pid" == "$$" ]] && return 0
  for existing in "${PIDS[@]:-}"; do
    [[ "$existing" == "$pid" ]] && return 0
  done
  PIDS+=("$pid")
}

collect_build_db_lockers() {
  local db_path="$1"
  [[ -f "$db_path" ]] || return 0
  say "Inspecting lock holders: $db_path"
  while IFS= read -r pid; do
    add_pid "$pid"
  done < <(lsof -t "$db_path" 2>/dev/null || true)
}

collect_project_build_processes() {
  local target_dir="$1"
  while IFS= read -r line; do
    local pid command
    pid="$(awk '{print $1}' <<<"$line")"
    command="${line#"$pid"}"
    command="${command#"${command%%[![:space:]]*}"}"
    if [[ "$command" == *"$target_dir"* || "$command" == *"$PROJECT_PATH"* ]]; then
      case "$command" in
        *xcodebuild*|*XCBBuildService*|*SWBBuildService*|*swift-frontend*|*swiftc*|*clang*|*actool*|*ibtool*)
          add_pid "$pid"
          ;;
      esac
    fi
  done < <(ps -axo pid=,command=)
}

collect_project_index_processes() {
  [[ "$INCLUDE_INDEX" == "1" ]] || return 0
  while IFS= read -r line; do
    local pid command
    pid="$(awk '{print $1}' <<<"$line")"
    command="${line#"$pid"}"
    command="${command#"${command%%[![:space:]]*}"}"
    if [[ "$command" == *"$PROJECT_PATH"* || "$command" == *"$PROJECT_NAME"* ]]; then
      case "$command" in
        *com.apple.dt.SKAgent*|*SourceKitService*|*swift-frontend*|*swiftc*)
          add_pid "$pid"
          ;;
      esac
    fi
  done < <(ps -axo pid=,command=)
}

while IFS= read -r target_dir; do
  [[ -z "$target_dir" ]] && continue
  TARGET_DIRS+=("$target_dir")
  collect_build_db_lockers "$target_dir/Build/Intermediates.noindex/XCBuildData/build.db"
  collect_project_build_processes "$target_dir"
done < <(find "$DERIVED_DATA_ROOT" -maxdepth 1 -type d -name "${PROJECT_NAME}-*" 2>/dev/null | sort)

collect_project_index_processes

if [[ "${#TARGET_DIRS[@]}" -eq 0 ]]; then
  say "No DerivedData folders found for project prefix: $PROJECT_NAME"
fi

if [[ "${#PIDS[@]}" -eq 0 ]]; then
  say "No matching Xcode build lock/process found."
  exit 0
fi

say "Stopping PIDs: ${PIDS[*]}"
ps -o pid,ppid,stat,etime,command -p "$(IFS=,; echo "${PIDS[*]}")" || true
kill "-$SIGNAL" "${PIDS[@]}" 2>/dev/null || true

sleep 2

declare -a ALIVE=()
for pid in "${PIDS[@]}"; do
  if kill -0 "$pid" 2>/dev/null; then
    ALIVE+=("$pid")
  fi
done

if [[ "${#ALIVE[@]}" -gt 0 && "$FORCE" == "1" ]]; then
  warn "Still alive after SIG$SIGNAL; sending SIGKILL to: ${ALIVE[*]}"
  kill -KILL "${ALIVE[@]}" 2>/dev/null || true
  sleep 1
fi

say "Remaining matching build.db lockers:"
while IFS= read -r target_dir; do
  db_path="$target_dir/Build/Intermediates.noindex/XCBuildData/build.db"
  [[ -f "$db_path" ]] || continue
  lsof "$db_path" 2>/dev/null || true
done < <(printf '%s\n' "${TARGET_DIRS[@]:-}")

say "Done."
