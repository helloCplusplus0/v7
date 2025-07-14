#!/bin/bash
# 🚀 启动Web前端开发服务器（绕过代理）

echo "🔧 设置开发环境变量..."

# 设置代理绕过 - 同时设置大小写版本
export NO_PROXY="localhost,127.0.0.1,::1,192.168.31.84"
export no_proxy="localhost,127.0.0.1,::1,192.168.31.84"

# 清除可能的代理设置
unset HTTP_PROXY
unset HTTPS_PROXY
unset http_proxy
unset https_proxy

# 设置gRPC-Web配置
export VITE_GRPC_WEB_URL="http://192.168.31.84:50053"
export VITE_API_BASE_URL="http://192.168.31.84:50053"

# 开发模式配置
export VITE_ENABLE_DEBUG=true
export VITE_ENABLE_DEV_MODE=true
export VITE_API_TIMEOUT=30000

echo "✅ 环境变量已设置："
echo "   NO_PROXY: $NO_PROXY"
echo "   no_proxy: $no_proxy"
echo "   VITE_GRPC_WEB_URL: $VITE_GRPC_WEB_URL"
echo "   VITE_API_BASE_URL: $VITE_API_BASE_URL"

echo ""
echo "🧪 测试后端连接..."
if curl -s --max-time 5 "http://192.168.31.84:50053/v7.backend.BackendService/HealthCheck" > /dev/null; then
    echo "✅ 后端服务连接正常"
else
    echo "⚠️ 后端服务连接异常，请检查backend服务是否运行"
fi

echo ""
echo "🚀 启动前端开发服务器..."
echo "   访问地址: http://192.168.31.84:5173"
echo "   测试页面: http://192.168.31.84:5173/simple-test.html"
echo "   完整测试: http://192.168.31.84:5173/test-grpc-connection.html"
echo "   后端地址: http://192.168.31.84:50053"

# 启动开发服务器
npm run dev 