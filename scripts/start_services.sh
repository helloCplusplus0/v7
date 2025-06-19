#!/bin/bash

echo "🚀 启动 fmod_slice MVP 服务..."

# 检查是否在正确的目录
if [ ! -d "backend" ] || [ ! -d "web" ]; then
    echo "❌ 错误：请在 test_project 目录下运行此脚本"
    exit 1
fi

# 启动后端服务
echo "📦 启动后端服务 (Rust + Axum)..."
cd backend
cargo run &
BACKEND_PID=$!
cd ..

# 等待后端启动
echo "⏳ 等待后端服务启动..."
sleep 3

# 启动前端服务
echo "🌐 启动前端服务 (Vite + SolidJS)..."
cd web
npm run dev &
FRONTEND_PID=$!
cd ..

echo "✅ 服务启动完成！"
echo ""
echo "📋 服务信息："
echo "  - 后端 API: http://localhost:3000"
echo "  - 前端应用: http://localhost:5173"
echo "  - 测试页面: file://$(pwd)/test_navigation.html"
echo ""
echo "🧪 测试步骤："
echo "  1. 打开 test_navigation.html 查看测试指南"
echo "  2. 访问 http://localhost:5173 查看 Dashboard"
echo "  3. 点击 Hello FMOD 卡片进入详细页面"
echo "  4. 测试消息发送和计数器功能"
echo ""
echo "⚠️  按 Ctrl+C 停止所有服务"

# 等待用户中断
trap "echo '🛑 正在停止服务...'; kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; exit 0" INT

# 保持脚本运行
wait 