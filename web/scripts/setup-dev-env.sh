#!/bin/bash
# 🔧 Web前端开发环境设置脚本

echo "🔧 设置V7 Web前端开发环境..."

# 创建环境变量文件
cat > .env.development << 'EOF'
# Web前端开发环境配置
# Connect代理地址 - 运行在Ubuntu主机上
VITE_API_BASE_URL=http://192.168.31.84:8080/api

# 应用标题
VITE_APP_TITLE=FMOD v7 Web Application [DEV]

# API超时时间（毫秒）
VITE_API_TIMEOUT=30000

# 开发服务器配置
VITE_DEV_SERVER_HOST=0.0.0.0
VITE_DEV_SERVER_PORT=5173

# HMR配置
VITE_HMR_HOST=192.168.31.84
VITE_HMR_PORT=5174

# 功能开关
VITE_ENABLE_DEBUG=true
VITE_ENABLE_HMR=true
VITE_ENABLE_SOURCE_MAP=true
VITE_ENABLE_COVERAGE=true

# Mock策略
VITE_MOCK_STRATEGY=disabled
VITE_MOCK_SHOW_INDICATOR=false
VITE_MOCK_LOG_REQUESTS=true
EOF

echo "✅ .env.development 文件已创建"

# 设置执行权限
chmod +x scripts/*.sh

echo "🎯 当前配置："
echo "  API Base URL: http://192.168.31.84:8080/api"
echo "  Web Dev Server: http://0.0.0.0:5173"
echo "  Connect代理: http://192.168.31.84:8080"

echo ""
echo "🚀 启动步骤："
echo "  1. 启动Backend gRPC服务 (端口50053)"
echo "  2. 启动Connect代理: cd web/shared/proxy && ./start-dev.sh"
echo "  3. 启动Web前端: npm run dev"

echo ""
echo "🔗 访问地址："
echo "  前端应用: http://192.168.31.84:5173"
echo "  Connect代理健康检查: http://192.168.31.84:8080/health" 