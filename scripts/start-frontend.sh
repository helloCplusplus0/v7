#!/bin/bash

# FMOD v7 前端启动脚本

# 获取脚本所在目录的上级目录（项目根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 切换到前端目录
cd "$PROJECT_ROOT/web"

echo "🎨 启动 FMOD v7 前端开发服务器..."
echo "📁 前端目录: $PROJECT_ROOT/web"
echo "🌐 开发服务器地址: http://localhost:5173"
echo ""

# 检查是否安装了 node_modules
if [ ! -d "node_modules" ]; then
    echo "📦 安装依赖..."
    npm install
    echo ""
fi

echo "🚀 启动开发服务器..."

# 启动前端开发服务器
npm run dev 