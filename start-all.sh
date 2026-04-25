#!/bin/bash

echo "🚀 启动 Raver 服务"
echo "=================="
echo ""

# 检查端口
check_port() {
  lsof -ti:$1 > /dev/null 2>&1
}

# 启动后端
echo "📡 检查后端服务器 (端口 3901)..."
if check_port 3901; then
  echo "✅ 后端服务器已在运行"
else
  echo "🔄 启动后端服务器..."
  cd server
  pnpm dev > ../server.log 2>&1 &
  SERVER_PID=$!
  echo "✅ 后端服务器已启动 (PID: $SERVER_PID)"
  cd ..
  sleep 3
fi

# 检查后端健康
echo ""
echo "🏥 检查后端健康状态..."
HEALTH=$(curl -s http://localhost:3901/health 2>/dev/null)
if [ $? -eq 0 ]; then
  echo "✅ 后端服务器健康"
else
  echo "❌ 后端服务器未响应，请检查 server.log"
  exit 1
fi

# 启动前端
echo ""
echo "🌐 检查前端服务器 (端口 3000)..."
if check_port 3000; then
  echo "✅ 前端服务器已在运行"
else
  echo "🔄 启动前端服务器..."
  cd web
  pnpm dev > ../web.log 2>&1 &
  WEB_PID=$!
  echo "✅ 前端服务器已启动 (PID: $WEB_PID)"
  cd ..
fi

echo ""
echo "🎉 所有服务已启动！"
echo ""
echo "📍 访问地址:"
echo "   前端: http://localhost:3000"
echo "   后端: http://localhost:3901"
echo ""
echo "📝 日志文件:"
echo "   后端: server.log"
echo "   前端: web.log"
echo ""
echo "🛑 停止服务:"
echo "   pkill -f 'pnpm dev'"
