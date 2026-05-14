#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$ROOT_DIR/server"
WEB_DIR="$ROOT_DIR/web"
WEB_TOOL_DIR="$ROOT_DIR/scrapRave"

API_PORT="${API_PORT:-3901}"
WEB_TOOL_PORT="${WEB_TOOL_PORT:-8000}"
WEB_PORT="${WEB_PORT:-3000}"

API_ORIGIN="http://127.0.0.1:$API_PORT"
WEB_TOOL_ORIGIN="http://127.0.0.1:$WEB_TOOL_PORT"

SERVER_LOG="$ROOT_DIR/server.log"
WEB_TOOL_LOG="$ROOT_DIR/webtool.log"
WEB_LOG="$ROOT_DIR/web.log"

START_MODE="${START_MODE:-terminals}"
RESTART_EXISTING="${RESTART_EXISTING:-1}"

usage() {
  cat <<EOF
用法:
  ./start-all.sh [--terminals|--background] [--no-restart]

选项:
  --terminals   在 macOS Terminal 中分别打开后端、WebTool、Web，实时显示日志（默认）
  --background  使用 nohup 后台启动，并写入 server.log / webtool.log / web.log
  --no-restart  不主动关闭已占用端口的旧进程

环境变量:
  START_MODE=terminals|background
  RESTART_EXISTING=1|0
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --terminals|--terminal)
      START_MODE="terminals"
      ;;
    --background|--nohup)
      START_MODE="background"
      ;;
    --no-restart)
      RESTART_EXISTING="0"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

check_port() {
  lsof -tiTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

kill_port() {
  local port="$1"
  local name="$2"
  local pids

  pids=$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)
  if [ -z "$pids" ]; then
    return
  fi

  echo "⛔ 关闭占用 $name 端口($port)的旧进程: $pids"
  kill $pids 2>/dev/null || true
  sleep 1

  pids=$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)
  if [ -n "$pids" ]; then
    echo "⚠️  强制关闭仍在占用 $name 端口($port)的进程: $pids"
    kill -9 $pids 2>/dev/null || true
  fi
}

shell_quote() {
  printf "%q" "$1"
}

escape_osascript_string() {
  sed 's/\\/\\\\/g; s/"/\\"/g'
}

open_terminal() {
  local title="$1"
  local command="$2"
  local escaped

  if ! command -v osascript >/dev/null 2>&1; then
    echo "❌ 当前环境没有 osascript，无法自动打开 macOS Terminal"
    echo "   可以改用: ./start-all.sh --background"
    return 1
  fi

  escaped=$(printf '%s' "$command" | escape_osascript_string)
  osascript <<OSA >/dev/null
tell application "Terminal"
  activate
  do script "$escaped"
end tell
OSA
}

wait_http() {
  local url="$1"
  local name="$2"
  local retries="${3:-60}"

  echo "⏳ 等待 $name: $url"
  for ((i=1; i<=retries; i++)); do
    local code
    code=$(curl -s -o /dev/null -w '%{http_code}' "$url" || true)
    if [[ "$code" =~ ^(2|3)[0-9][0-9]$ ]]; then
      echo "✅ $name 已就绪"
      return 0
    fi
    sleep 1
  done

  echo "❌ $name 启动超时，请查看日志"
  return 1
}

start_server() {
  echo "📡 检查主后端 (端口 $API_PORT)..."
  if check_port "$API_PORT"; then
    echo "✅ 主后端已在运行"
    return
  fi

  echo "🔄 启动主后端..."
  if [ "$START_MODE" = "terminals" ]; then
    local cmd
    cmd="cd $(shell_quote "$ROOT_DIR"); printf '\\033]0;Raver 主后端\\007'; echo '📡 Raver 主后端日志'; echo '目录: $SERVER_DIR'; echo; echo \$\$ > $(shell_quote "$ROOT_DIR/.server.pid"); env PORT=$(shell_quote "$API_PORT") pnpm -C $(shell_quote "$SERVER_DIR") dev"
    open_terminal "Raver 主后端" "$cmd"
    echo "✅ 主后端已在新 Terminal 中启动"
  else
    nohup env PORT="$API_PORT" pnpm -C "$SERVER_DIR" dev > "$SERVER_LOG" 2>&1 &
    echo $! > "$ROOT_DIR/.server.pid"
    echo "✅ 主后端启动中 (PID: $(cat "$ROOT_DIR/.server.pid"))"
  fi
}

start_web_tool() {
  echo "🧰 检查 Festival Viewer WebTool (端口 $WEB_TOOL_PORT)..."
  if check_port "$WEB_TOOL_PORT"; then
    echo "✅ Festival Viewer WebTool 已在运行"
    return
  fi

  echo "🔄 启动 Festival Viewer WebTool..."
  if [ "$START_MODE" = "terminals" ]; then
    local cmd
    cmd="cd $(shell_quote "$ROOT_DIR"); printf '\\033]0;Raver WebTool\\007'; echo '🧰 Festival Viewer WebTool 日志'; echo '目录: $WEB_TOOL_DIR'; echo; echo \$\$ > $(shell_quote "$ROOT_DIR/.webtool.pid"); env RAVER_BFF_BASE=$(shell_quote "$API_ORIGIN") python3 $(shell_quote "$WEB_TOOL_DIR/web_tool/server.py")"
    open_terminal "Raver WebTool" "$cmd"
    echo "✅ WebTool 已在新 Terminal 中启动"
  else
    nohup env RAVER_BFF_BASE="$API_ORIGIN" python3 "$WEB_TOOL_DIR/web_tool/server.py" > "$WEB_TOOL_LOG" 2>&1 &
    echo $! > "$ROOT_DIR/.webtool.pid"
    echo "✅ WebTool 启动中 (PID: $(cat "$ROOT_DIR/.webtool.pid"))"
  fi
}

start_web() {
  echo "🌐 检查 Web 前端 (端口 $WEB_PORT)..."
  if check_port "$WEB_PORT"; then
    echo "✅ Web 前端已在运行"
    return
  fi

  echo "🔄 启动 Web 前端..."
  if [ "$START_MODE" = "terminals" ]; then
    local cmd
    cmd="cd $(shell_quote "$ROOT_DIR"); printf '\\033]0;Raver Web 前端\\007'; echo '🌐 Raver Web 前端日志'; echo '目录: $WEB_DIR'; echo; echo \$\$ > $(shell_quote "$ROOT_DIR/.web.pid"); env NEXT_PUBLIC_API_URL=$(shell_quote "$API_ORIGIN/api") FESTIVAL_VIEWER_ORIGIN=$(shell_quote "$WEB_TOOL_ORIGIN") pnpm -C $(shell_quote "$WEB_DIR") dev"
    open_terminal "Raver Web 前端" "$cmd"
    echo "✅ Web 前端已在新 Terminal 中启动"
  else
    nohup env \
      NEXT_PUBLIC_API_URL="$API_ORIGIN/api" \
      FESTIVAL_VIEWER_ORIGIN="$WEB_TOOL_ORIGIN" \
      pnpm -C "$WEB_DIR" dev > "$WEB_LOG" 2>&1 &
    echo $! > "$ROOT_DIR/.web.pid"
    echo "✅ Web 前端启动中 (PID: $(cat "$ROOT_DIR/.web.pid"))"
  fi
}

echo "🚀 启动 Raver 本地开发服务"
echo "================================"
echo "启动模式: $START_MODE"
echo ""

if [ "$START_MODE" = "terminals" ] && [ "$RESTART_EXISTING" = "1" ]; then
  echo "🧹 Terminal 实时日志模式会先关闭旧进程，以便新窗口接管日志输出"
  kill_port "$API_PORT" "主后端"
  kill_port "$WEB_TOOL_PORT" "Festival Viewer WebTool"
  kill_port "$WEB_PORT" "Web 前端"
  echo ""
fi

start_server
wait_http "$API_ORIGIN/health" "主后端"

start_web_tool
wait_http "$WEB_TOOL_ORIGIN/festival-viewer.html" "Festival Viewer WebTool"

start_web
wait_http "http://127.0.0.1:$WEB_PORT" "Web 前端"

echo ""
echo "🎉 所有服务已启动"
echo ""
echo "📍 访问地址:"
echo "   Web:              http://127.0.0.1:$WEB_PORT"
echo "   后台工作台:        http://127.0.0.1:$WEB_PORT/admin"
echo "   Content CMS:      http://127.0.0.1:$WEB_PORT/admin/content-cms"
echo "   Festival Viewer:  http://127.0.0.1:$WEB_PORT/admin/festival-viewer.html"
echo "   主后端:            $API_ORIGIN"
echo "   WebTool:          $WEB_TOOL_ORIGIN"
echo ""
if [ "$START_MODE" = "background" ]; then
  echo "📝 日志文件:"
  echo "   主后端:   $SERVER_LOG"
  echo "   WebTool:  $WEB_TOOL_LOG"
  echo "   Web:      $WEB_LOG"
  echo ""
fi
echo "🛑 停止服务:"
echo "   kill \$(cat .server.pid .webtool.pid .web.pid 2>/dev/null) 2>/dev/null || true"
echo "   或按端口关闭: lsof -tiTCP:$API_PORT -tiTCP:$WEB_TOOL_PORT -tiTCP:$WEB_PORT -sTCP:LISTEN | xargs kill"
