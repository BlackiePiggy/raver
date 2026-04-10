#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=""
WRITE_ALLOWLIST=0

for arg in "$@"; do
  case "$arg" in
    --write-allowlist)
      WRITE_ALLOWLIST=1
      ;;
    *)
      if [[ -z "$ROOT_DIR" ]]; then
        ROOT_DIR="$arg"
      else
        echo "error: unexpected argument: $arg"
        echo "usage: scripts/check-modal-allowlist.sh [repo-root] [--write-allowlist]"
        exit 2
      fi
      ;;
  esac
done

if [[ -z "$ROOT_DIR" ]]; then
  ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

IOS_DIR="$ROOT_DIR/mobile/ios/RaverMVP/RaverMVP"
ALLOWLIST_FILE="$ROOT_DIR/scripts/modal-allowlist-signatures.txt"

if [[ ! -d "$IOS_DIR" ]]; then
  echo "error: iOS project directory not found: $IOS_DIR"
  exit 2
fi

if [[ ! -f "$ALLOWLIST_FILE" ]]; then
  echo "error: modal allowlist file not found: $ALLOWLIST_FILE"
  exit 2
fi

collect_modal_signatures_raw() {
  find "$IOS_DIR" -name '*.swift' | LC_ALL=C sort | while IFS= read -r file; do
    local rel_file="${file#$ROOT_DIR/}"
    awk -v file="$rel_file" '
function extract_binding(segment, token) {
  if (match(segment, /\$[A-Za-z_][A-Za-z0-9_]*/)) {
    return substr(segment, RSTART, RLENGTH)
  }
  if (match(segment, /get:[[:space:]]*\{[[:space:]]*[A-Za-z_][A-Za-z0-9_]*/)) {
    token = substr(segment, RSTART, RLENGTH)
    sub(/^.*get:[[:space:]]*\{[[:space:]]*/, "", token)
    return token
  }
  if (match(segment, /isPresented:[[:space:]]*[A-Za-z_][A-Za-z0-9_]*/)) {
    token = substr(segment, RSTART, RLENGTH)
    sub(/^.*isPresented:[[:space:]]*/, "", token)
    if (token != "Binding") {
      return token
    }
  }
  if (match(segment, /item:[[:space:]]*[A-Za-z_][A-Za-z0-9_]*/)) {
    token = substr(segment, RSTART, RLENGTH)
    sub(/^.*item:[[:space:]]*/, "", token)
    if (token != "Binding") {
      return token
    }
  }
  return "$unknown"
}

{ lines[NR] = $0 }

END {
  for (i = 1; i <= NR; i++) {
    line = lines[i]
    kind = ""
    if (line ~ /\.sheet\(/) {
      kind = "sheet"
    } else if (line ~ /\.fullScreenCover\(/) {
      kind = "fullScreenCover"
    }

    if (kind == "") {
      continue
    }

    segment = ""
    for (j = i; j <= i + 8 && j <= NR; j++) {
      segment = segment "\n" lines[j]
    }

    binding = extract_binding(segment)
    print file "|" kind "|" binding
  }
}
' "$file"
  done
}

collect_modal_signatures() {
  collect_modal_signatures_raw \
    | LC_ALL=C sort \
    | uniq -c \
    | awk '{ count = $1; $1 = ""; sub(/^ /, ""); print count "|" $0 }'
}

canonical_sort_signatures() {
  LC_ALL=C sort -t'|' -k2,2 -k3,3 -k4,4 -k1,1n
}

actual_tmp="$(mktemp)"
expected_tmp="$(mktemp)"
diff_tmp="$(mktemp)"
trap 'rm -f "$actual_tmp" "$expected_tmp" "$diff_tmp"' EXIT

collect_modal_signatures | canonical_sort_signatures > "$actual_tmp"

if rg -q '\|\$unknown$' "$actual_tmp"; then
  echo "[FAIL] Unable to infer modal binding variable for some call sites."
  rg -n '\|\$unknown$' "$actual_tmp"
  echo "Please refine signature extraction before updating allowlist."
  exit 1
fi

if [[ "$WRITE_ALLOWLIST" -eq 1 ]]; then
  cp "$actual_tmp" "$ALLOWLIST_FILE"
  echo "Modal allowlist updated: $ALLOWLIST_FILE"
  exit 0
fi

grep -v '^[[:space:]]*#' "$ALLOWLIST_FILE" | sed '/^[[:space:]]*$/d' | canonical_sort_signatures > "$expected_tmp"

if diff -u "$expected_tmp" "$actual_tmp" > "$diff_tmp"; then
  echo "[PASS] Modal allowlist matches current sheet/fullScreenCover usage."
  echo "Modal allowlist check passed."
  exit 0
fi

echo "[FAIL] Modal usage differs from allowlist: $ALLOWLIST_FILE"
cat "$diff_tmp"
echo
echo "If this modal change is intentional and approved, refresh allowlist via:"
echo "  scripts/check-modal-allowlist.sh --write-allowlist"
exit 1
