#!/bin/bash

# FMOD v7 全栈项目启动脚本
# 同时启动前后端服务器

# 获取脚本所在目录的上级目录（项目根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 切换到项目根目录
cd "$PROJECT_ROOT"

echo "🚀 启动 FMOD v7 全栈项目..."
echo "📁 项目根目录: $PROJECT_ROOT"
echo ""
echo "🏗️  架构说明:"
echo "   📦 前端: SolidJS + Vite (端口 5173)"
echo "   ⚙️  后端: Rust + FMOD v7 (端口 3000)"
echo "   🗄️  数据库: SQLite (backend/data/dev.db)"
echo ""

# 确保backend/data目录存在
mkdir -p backend/data

# 检查是否已安装 concurrently
if ! npm list concurrently > /dev/null 2>&1; then
    echo "📦 安装 concurrently..."
    npm install
fi

# 检查前端依赖
if [ ! -d "web/node_modules" ]; then
    echo "📦 安装前端依赖..."
    cd web && npm install && cd ..
fi

echo ""
echo "🔧 启动前后端服务器..."
echo "🌐 前端开发服务器: http://localhost:5173"
echo "🔌 后端 API 服务器: http://localhost:3000"
echo ""
echo "按 Ctrl+C 停止所有服务器"
echo "=" * 50

# 使用 concurrently 同时启动前后端
npm run dev 