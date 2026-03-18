#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEB_DIR="$ROOT_DIR/web"
SERVER_DIR="$ROOT_DIR/server"
WEB_PORT=3000
API_PORT=3001

detect_lan_ip() {
  local ip
  ip=$(ipconfig getifaddr en0 2>/dev/null || true)
  if [ -z "$ip" ]; then
    ip=$(ipconfig getifaddr en1 2>/dev/null || true)
  fi
  if [ -z "$ip" ]; then
    ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
  fi
  if [ -z "$ip" ]; then
    ip="127.0.0.1"
  fi
  echo "$ip"
}

kill_port() {
  local port="$1"
  local name="$2"
  local pids

  pids=$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)
  if [ -n "$pids" ]; then
    echo "⛔ 关闭占用 $name 端口($port)的旧进程: $pids"
    kill $pids 2>/dev/null || true
    sleep 1

    pids=$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)
    if [ -n "$pids" ]; then
      echo "⚠️  强制关闭仍在占用端口的进程: $pids"
      kill -9 $pids 2>/dev/null || true
    fi
  else
    echo "✅ $name 端口($port)当前无占用"
  fi
}

wait_http() {
  local url="$1"
  local name="$2"
  local retries=30

  echo "⏳ 等待${name}启动: $url"
  for ((i=1; i<=retries; i++)); do
    local code
    code=$(curl -s -o /dev/null -w '%{http_code}' "$url" || true)
    if [ "$code" = "200" ]; then
      echo "✅ $name 启动成功"
      return 0
    fi
    sleep 1
  done

  echo "❌ $name 启动超时，请查看日志"
  return 1
}

echo "🔄 重启 Raver 前后端服务"

echo "1) 清理旧服务"
kill_port "$WEB_PORT" "前端"
kill_port "$API_PORT" "后端"

echo "2) 清理前端缓存"
rm -rf "$WEB_DIR/.next"

echo "3) 启动后端"
nohup pnpm -C "$SERVER_DIR" exec ts-node src/index.ts > "$ROOT_DIR/server.log" 2>&1 &
echo $! > "$ROOT_DIR/.server.pid"

echo "4) 启动前端"
LAN_IP=$(detect_lan_ip)
echo "🌐 检测到局域网IP: $LAN_IP"
nohup env NEXT_PUBLIC_API_URL="http://$LAN_IP:$API_PORT/api" pnpm -C "$WEB_DIR" exec next dev -H 0.0.0.0 -p "$WEB_PORT" > "$ROOT_DIR/web.log" 2>&1 &
echo $! > "$ROOT_DIR/.web.pid"

wait_http "http://localhost:$API_PORT/health" "后端"
wait_http "http://localhost:$WEB_PORT" "前端"

echo ""
echo "🎉 重启完成"
echo "前端: http://localhost:$WEB_PORT"
echo "前端(局域网): http://$LAN_IP:$WEB_PORT"
echo "后端: http://localhost:$API_PORT"
echo "后端(局域网): http://$LAN_IP:$API_PORT"
echo "前端已注入 NEXT_PUBLIC_API_URL=http://$LAN_IP:$API_PORT/api"
echo "日志: $ROOT_DIR/web.log / $ROOT_DIR/server.log"
