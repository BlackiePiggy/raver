#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
REPORT_ROOT="$ROOT_DIR/docs/reports"
RUN_DIR="${1:-}"
MAX_TAIL_LINES="${OPENIM_PROBE_DIGEST_MAX_LINES:-12}"
SIM1_LINES=0
SIM2_LINES=0
SIM1_APP_EVENTS=0
SIM2_APP_EVENTS=0

if [[ -z "$RUN_DIR" ]]; then
  RUN_DIR="$(ls -dt "$REPORT_ROOT"/openim-dual-sim-* 2>/dev/null | head -n1 || true)"
fi

if [[ -z "$RUN_DIR" || ! -d "$RUN_DIR" ]]; then
  echo "[digest] no probe report found"
  exit 1
fi

pick_source() {
  local sim="$1"
  local focus="$RUN_DIR/${sim}.focus.log"
  local raw="$RUN_DIR/${sim}.log"

  if [[ -s "$focus" ]]; then
    echo "$focus"
  else
    echo "$raw"
  fi
}

count_or_zero() {
  local pattern="$1"
  local file="$2"
  rg -ci "$pattern" "$file" 2>/dev/null || echo 0
}

classify() {
  local connected="$1"
  local unavailable="$2"
  local login10102="$3"
  local realtime="$4"
  local catchup="$5"
  local fallback="$6"
  local app_events="$7"

  if [[ "$app_events" -eq 0 ]]; then
    echo "无有效 App/OpenIM 事件（采集窗口内可能未登录或未触发聊天路径）"
    return
  fi

  if [[ "$login10102" -gt 0 ]]; then
    echo "可能重复登录冲突（10102）"
    return
  fi

  if [[ "$connected" -eq 0 && "$unavailable" -gt 0 ]]; then
    echo "会话未建立（OpenIM unavailable）"
    return
  fi

  if [[ "$realtime" -gt 0 && "$catchup" -eq 0 ]]; then
    echo "实时链路主导（理想）"
    return
  fi

  if [[ "$realtime" -gt 0 && "$catchup" -gt 0 ]]; then
    echo "实时 + 补偿并存（可用，需压低 catchup）"
    return
  fi

  if [[ "$realtime" -eq 0 && "$catchup" -gt 0 ]]; then
    echo "主要依赖 catchup（实时链路异常）"
    return
  fi

  if [[ "$fallback" -gt 0 ]]; then
    echo "检测到 fallback 路径"
    return
  fi

  echo "证据不足（建议用 stream 模式复测）"
}

print_sim_digest() {
  local sim_name="$1"
  local src="$2"
  local err_file
  local connected unavailable login10102 realtime catchup fallback app_events
  local send_failed send_failure_hint resend_failed
  local pagination_trigger scroll_auto_yes scroll_auto_no jump_visible_on jump_visible_off
  local global_trigger global_submit global_result global_result_selected global_failed
  local conversation_submit conversation_result conversation_result_empty conversation_select conversation_failed
  local search_focus_request search_reveal_hit search_reveal_miss search_reveal_load_older
  local search_pending_consume search_pending_reveal
  local verdict

  err_file="$RUN_DIR/$(echo "$sim_name" | tr '[:upper:]' '[:lower:]').err.log"

  if [[ ! -f "$src" ]]; then
    echo "[$sim_name]"
    echo "  source: $src (missing)"
    echo "  verdict: 采集失败（日志文件不存在）"
    if [[ -s "$err_file" ]]; then
      echo "  stderr tail:"
      tail -n "$MAX_TAIL_LINES" "$err_file"
    fi
    echo
    return
  fi

  connected="$(count_or_zero 'state -> connected' "$src")"
  unavailable="$(count_or_zero 'OpenIM .* unavailable|state -> unavailable' "$src")"
  login10102="$(count_or_zero '10102|logged in repeatedly' "$src")"
  realtime="$(count_or_zero 'realtime message received|badge recompute source=openim-realtime|onRecvNewMessage' "$src")"
  catchup="$(count_or_zero 'catchup messages changed|catchup conversations changed' "$src")"
  fallback="$(count_or_zero 'fallback to BFF' "$src")"
  app_events="$(count_or_zero '\[AppState\]|\[OpenIMSession\]|\[OpenIMChatStore\]|\[ConversationLoader\]|\[DemoAlignedChat\]|\[DemoAlignedPagination\]|\[DemoAlignedViewport\]|\[DemoAlignedScroll\]|\[DemoAlignedMessageFlow\]|\[GlobalSearch\]|\[DemoAlignedSearch\]' "$src")"
  send_failed="$(count_or_zero '\[DemoAlignedChat\] send (text|image|video) failed' "$src")"
  resend_failed="$(count_or_zero '\[DemoAlignedChat\] resend failed' "$src")"
  send_failure_hint="$(count_or_zero '\[DemoAlignedChat\] send failure hint shown' "$src")"
  pagination_trigger="$(count_or_zero '\[DemoAlignedPagination\] trigger load-older' "$src")"
  scroll_auto_yes="$(count_or_zero '\[DemoAlignedScroll\] auto-scroll decision result=1' "$src")"
  scroll_auto_no="$(count_or_zero '\[DemoAlignedScroll\] auto-scroll decision result=0' "$src")"
  jump_visible_on="$(count_or_zero '\[DemoAlignedViewport\] jump-visible state=1' "$src")"
  jump_visible_off="$(count_or_zero '\[DemoAlignedViewport\] jump-visible state=0' "$src")"
  global_trigger="$(count_or_zero '\[GlobalSearch\] trigger' "$src")"
  global_submit="$(count_or_zero '\[GlobalSearch\] submit' "$src")"
  global_result="$(count_or_zero '\[GlobalSearch\] result query=' "$src")"
  global_result_selected="$(count_or_zero '\[GlobalSearch\] result-selected' "$src")"
  global_failed="$(count_or_zero '\[GlobalSearch\] failed' "$src")"
  conversation_submit="$(count_or_zero '\[DemoAlignedSearch\] submit' "$src")"
  conversation_result="$(count_or_zero '\[DemoAlignedSearch\] result query=' "$src")"
  conversation_result_empty="$(count_or_zero '\[DemoAlignedSearch\] result-empty' "$src")"
  conversation_select="$(count_or_zero '\[DemoAlignedSearch\] result-selected' "$src")"
  conversation_failed="$(count_or_zero '\[DemoAlignedSearch\] failed' "$src")"
  search_focus_request="$(count_or_zero '\[DemoAlignedSearch\] focus-request' "$src")"
  search_reveal_hit="$(count_or_zero '\[DemoAlignedSearch\] reveal-hit' "$src")"
  search_reveal_miss="$(count_or_zero '\[DemoAlignedSearch\] reveal-miss' "$src")"
  search_reveal_load_older="$(count_or_zero '\[DemoAlignedSearch\] reveal-load-older' "$src")"
  search_pending_consume="$(count_or_zero '\[DemoAlignedSearch\] pending-focus-consume' "$src")"
  search_pending_reveal="$(count_or_zero '\[DemoAlignedSearch\] pending-focus-reveal' "$src")"
  verdict="$(classify "$connected" "$unavailable" "$login10102" "$realtime" "$catchup" "$fallback" "$app_events")"

  echo "[$sim_name]"
  echo "  source: $src"
  local line_count
  line_count="$(wc -l < "$src" 2>/dev/null || echo 0)"
  echo "  lines: $line_count"
  if [[ "$sim_name" == "SIM1" ]]; then
    SIM1_LINES="$line_count"
    SIM1_APP_EVENTS="$app_events"
  else
    SIM2_LINES="$line_count"
    SIM2_APP_EVENTS="$app_events"
  fi
  echo "  appEvents=$app_events connected=$connected unavailable=$unavailable login10102=$login10102 realtime=$realtime catchup=$catchup fallback=$fallback"
  echo "  sendFailed=$send_failed resendFailed=$resend_failed failureHint=$send_failure_hint"
  echo "  paginationTrigger=$pagination_trigger autoScrollYes=$scroll_auto_yes autoScrollNo=$scroll_auto_no jumpShow=$jump_visible_on jumpHide=$jump_visible_off"
  echo "  searchGlobal trigger=$global_trigger submit=$global_submit result=$global_result selected=$global_result_selected failed=$global_failed"
  echo "  searchInConversation submit=$conversation_submit result=$conversation_result empty=$conversation_result_empty selected=$conversation_select failed=$conversation_failed"
  echo "  searchAnchor focusRequest=$search_focus_request revealHit=$search_reveal_hit revealMiss=$search_reveal_miss loadOlder=$search_reveal_load_older pendingConsume=$search_pending_consume pendingReveal=$search_pending_reveal"
  echo "  verdict: $verdict"
  if [[ ! -s "$src" ]]; then
    if [[ -s "$err_file" ]]; then
      echo "  stderr tail:"
      tail -n "$MAX_TAIL_LINES" "$err_file"
    else
      echo "  note: 日志为空，可能是该模拟器未成功产生日志或采集管道未建立。"
    fi
  fi
  echo "  key tail:"
  rg -i 'state ->|10102|logged in repeatedly|realtime message received|badge recompute source=openim-realtime|badge recompute source=community-event|catchup messages changed|catchup conversations changed|OpenIM .* unavailable|fallback to BFF|\[ConversationLoader\]|\[DemoAlignedChat\] send .* failed|\[DemoAlignedChat\] resend failed|\[DemoAlignedChat\] send failure hint shown|\[DemoAlignedPagination\]|\[DemoAlignedViewport\]|\[DemoAlignedScroll\]|\[DemoAlignedMessageFlow\]|\[GlobalSearch\]|\[DemoAlignedSearch\]' "$src" 2>/dev/null | tail -n "$MAX_TAIL_LINES" || true
  echo
}

SIM1_SRC="$(pick_source sim1)"
SIM2_SRC="$(pick_source sim2)"

echo "===== OpenIM Probe Digest ====="
echo "run: $RUN_DIR"
echo
print_sim_digest "SIM1" "$SIM1_SRC"
print_sim_digest "SIM2" "$SIM2_SRC"

if [[ "$SIM1_LINES" -eq 0 || "$SIM2_LINES" -eq 0 ]]; then
  echo "overall: 部分无效（至少一侧日志为 0 行），请重跑双机探针后再下结论。"
elif [[ "$SIM1_APP_EVENTS" -eq 0 || "$SIM2_APP_EVENTS" -eq 0 ]]; then
  echo "overall: 部分无效（至少一侧没有 App/OpenIM 事件），请确认两侧均已登录并触发聊天交互后复测。"
else
  echo "overall: 双侧日志有效，可用于判断实时链路与回退情况。"
fi
