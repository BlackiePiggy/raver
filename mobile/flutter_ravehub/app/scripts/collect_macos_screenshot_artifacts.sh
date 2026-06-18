#!/usr/bin/env bash
set -euo pipefail

DESTINATION_DIR="${1:-app/build/screenshots/flutter}"
mkdir -p "$DESTINATION_DIR"

if compgen -G "$DESTINATION_DIR/*.png" > /dev/null; then
  echo "Screenshots already exist in $DESTINATION_DIR"
  exit 0
fi

shopt -s nullglob

declare -a CANDIDATE_DIRS=()
if [[ -n "${TMPDIR:-}" ]]; then
  CANDIDATE_DIRS+=("${TMPDIR%/}/ravehub_screenshots")
fi

CANDIDATE_DIRS+=("/tmp/ravehub_screenshots")

for sandbox_dir in \
  "$HOME"/Library/Containers/*/Data/tmp/ravehub_screenshots \
  "$HOME"/Library/Containers/*/Data/Library/Caches/ravehub_screenshots; do
  CANDIDATE_DIRS+=("$sandbox_dir")
done

copied=0
for screenshot_dir in "${CANDIDATE_DIRS[@]}"; do
  if [[ ! -d "$screenshot_dir" ]]; then
    continue
  fi

  for screenshot_file in "$screenshot_dir"/*.png; do
    cp "$screenshot_file" "$DESTINATION_DIR/"
    copied=$((copied + 1))
  done
done

if [[ "$copied" -eq 0 ]]; then
  echo "No macOS sandbox screenshot artifacts found."
  exit 1
fi

echo "Collected $copied screenshot artifact(s) into $DESTINATION_DIR"
