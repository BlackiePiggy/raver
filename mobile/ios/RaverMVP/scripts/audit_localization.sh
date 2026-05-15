#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_DIR="$ROOT_DIR/RaverMVP"
OUTPUT_PATH="${1:-}"

if ! command -v rg >/dev/null 2>&1; then
  echo "error: ripgrep (rg) is required" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

collect() {
  local name="$1"
  local pattern="$2"
  local mode="${3:-default}"
  local out="$TMP_DIR/${name}.txt"

  if [[ "$mode" == "pcre2" ]]; then
    rg -n --pcre2 --glob '*.swift' "$pattern" "$SWIFT_DIR" >"$out" || true
  else
    rg -n --glob '*.swift' "$pattern" "$SWIFT_DIR" >"$out" || true
  fi
}

collect "l_calls" '(?<!func )\bL\(' "pcre2"
collect "ll_calls" '(?<!func )\bLL\(' "pcre2"
collect "lt_trilingual_calls" '\bLT\(\s*"[^"]*"\s*,\s*"[^"]*"\s*,\s*"[^"]*"\s*\)'
collect "l_trilingual_calls" '\bL\(\s*"[^"]*"\s*,\s*"[^"]*"\s*,\s*"[^"]*"\s*\)'
collect "l_two_arg_single_line" '\bL\(\s*"[^"]*"\s*,\s*"[^"]*"\s*\)'
collect "hardcoded_cjk_strings" '"(?:[^"\\]|\\.)*[\p{Han}\p{Hiragana}\p{Katakana}](?:[^"\\]|\\.)*"' "pcre2"
collect "hardcoded_english_ui_strings" '\b(Text|Label|Button|TextField|SecureField|ContentUnavailableView)\(\s*"[A-Za-z][^"]{2,}"'

# Keep compatibility helpers available in AppState.swift, but do not count their
# declarations as remaining legacy call sites.
for name in l_calls ll_calls l_trilingual_calls l_two_arg_single_line; do
  sed -i '' '/func L(/d; /func LL(/d' "$TMP_DIR/${name}.txt"
done

count_lines() {
  wc -l <"$TMP_DIR/$1.txt" | tr -d ' '
}

top_files() {
  local name="$1"
  awk -F: '{ count[$1] += 1 } END { for (file in count) print count[file], file }' "$TMP_DIR/$name.txt" \
    | sort -rn \
    | head -20 \
    | sed "s# $ROOT_DIR/# #"
}

emit_report() {
  cat <<EOF
# iOS Localization Audit

Root: $SWIFT_DIR
Generated: $(date '+%Y-%m-%d %H:%M:%S %z')

## Summary

- L calls: $(count_lines "l_calls")
- LL calls: $(count_lines "ll_calls")
- Explicit LT(zh,en,ja) calls: $(count_lines "lt_trilingual_calls")
- Explicit L(zh,en,ja) calls: $(count_lines "l_trilingual_calls")
- Single-line two-argument L calls: $(count_lines "l_two_arg_single_line")
- Hardcoded CJK string literals: $(count_lines "hardcoded_cjk_strings")
- Suspected hardcoded English UI literals: $(count_lines "hardcoded_english_ui_strings")

## Top Files: L Calls

EOF
  top_files "l_calls"

  cat <<EOF

## Top Files: LL Calls

EOF
  top_files "ll_calls"

  cat <<EOF

## Top Files: Hardcoded CJK Strings

EOF
  top_files "hardcoded_cjk_strings"

  cat <<EOF

## Top Files: Suspected Hardcoded English UI Strings

EOF
  top_files "hardcoded_english_ui_strings"

  for name in l_calls ll_calls lt_trilingual_calls l_trilingual_calls l_two_arg_single_line hardcoded_cjk_strings hardcoded_english_ui_strings; do
    cat <<EOF

## Detail: $name

EOF
    sed "s#$ROOT_DIR/##" "$TMP_DIR/$name.txt"
  done
}

if [[ -n "$OUTPUT_PATH" ]]; then
  mkdir -p "$(dirname "$OUTPUT_PATH")"
  emit_report >"$OUTPUT_PATH"
  echo "Localization audit written to $OUTPUT_PATH"
else
  emit_report
fi
