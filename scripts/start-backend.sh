#!/bin/bash

# FMOD v7 后端启动脚本

# 获取脚本所在目录的上级目录（项目根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 切换到后端目录
cd "$PROJECT_ROOT/backend"

echo "🔧 启动 FMOD v7 后端服务器..."
echo "📁 后端目录: $PROJECT_ROOT/backend"
echo "🗄️  数据库路径: ./backend/data/dev.db"
echo "🌐 服务器地址: http://localhost:3000"
echo ""

# 确保data目录存在
mkdir -p data

# 检查数据库是否存在
if [ -f "data/dev.db" ]; then
    echo "✅ 数据库文件已存在: data/dev.db"
else
    echo "ℹ️  数据库文件不存在，将在首次启动时创建"
fi

echo ""
echo "🚀 启动服务器..."

# 启动后端服务器
cargo run 