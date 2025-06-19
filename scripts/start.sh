#!/bin/bash

# FMOD v7 全栈项目启动脚本
# 同时启动前后端开发服务器

# 获取脚本所在目录的上级目录（项目根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 启动 FMOD v7 开发环境...${NC}"
echo -e "${BLUE}📁 项目根目录: $PROJECT_ROOT${NC}"
echo ""
echo -e "${GREEN}🏗️  开发环境说明:${NC}"
echo -e "   📦 前端: SolidJS + Vite (http://localhost:5173)"
echo -e "   ⚙️  后端: Rust + FMOD v7 (http://localhost:3000)"
echo -e "   🗄️  数据库: SQLite (backend/data/dev.db)"
echo ""

# 切换到项目根目录
cd "$PROJECT_ROOT"

# 确保backend/data目录存在
mkdir -p backend/data

# 检查前端依赖
if [ ! -d "web/node_modules" ]; then
    echo -e "${YELLOW}📦 安装前端依赖...${NC}"
    cd web && npm install && cd ..
fi

# 检查后端是否有Cargo.toml
if [ ! -f "backend/Cargo.toml" ]; then
    echo -e "${RED}❌ 错误: 找不到 backend/Cargo.toml${NC}"
    exit 1
fi

# 定义清理函数
cleanup() {
    echo -e "\n${YELLOW}🛑 正在停止服务...${NC}"
    # 杀死所有子进程
    jobs -p | xargs -r kill
    exit 0
}

# 捕获 Ctrl+C 信号
trap cleanup SIGINT SIGTERM

echo -e "${GREEN}🔧 启动开发服务器...${NC}"
echo -e "${GREEN}🌐 前端: http://localhost:5173${NC}"
echo -e "${GREEN}🔌 后端: http://localhost:3000${NC}"
echo ""
echo -e "${YELLOW}💡 使用方法:${NC}"
echo -e "   - 前端开发: 访问 http://localhost:5173"  
echo -e "   - API测试: 访问 http://localhost:3000"
echo -e "   - 停止服务: 按 Ctrl+C"
echo ""

# 启动后端服务器（在后台）
echo -e "${BLUE}🔌 启动后端服务器...${NC}"
cd "$PROJECT_ROOT/backend"
cargo run &
BACKEND_PID=$!

# 等待一下让后端启动
sleep 2

# 启动前端服务器（在后台）
echo -e "${BLUE}🌐 启动前端服务器...${NC}"
cd "$PROJECT_ROOT/web"
npm run dev &
FRONTEND_PID=$!

# 等待前端启动
sleep 3

echo ""
echo -e "${GREEN}✅ 开发环境已启动！${NC}"
echo -e "${GREEN}   📦 前端: http://localhost:5173${NC}"
echo -e "${GREEN}   ⚙️  后端: http://localhost:3000${NC}"
echo ""
echo -e "${YELLOW}📊 进程信息:${NC}"
echo -e "   后端进程ID: $BACKEND_PID"
echo -e "   前端进程ID: $FRONTEND_PID"
echo ""
echo -e "${YELLOW}按 Ctrl+C 停止所有服务${NC}"

# 等待子进程完成
wait 