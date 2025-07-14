#!/bin/bash

# Analytics Engine Run Script
# 启动分析引擎服务器

set -e

echo "🚀 Starting Analytics Engine Server..."

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认配置
LISTEN_ADDR=${ANALYTICS_LISTEN_ADDR:-"0.0.0.0:50051"}  # 统一使用50051端口
SOCKET_PATH=${ANALYTICS_SOCKET_PATH:-""}
BUILD_MODE=${BUILD_MODE:-"release"}
LOG_LEVEL=${RUST_LOG:-"info"}

# 显示配置
echo -e "${BLUE}📋 Configuration:${NC}"
echo -e "   Listen Address: ${LISTEN_ADDR}"
echo -e "   Socket Path: ${SOCKET_PATH:-"(not set)"}"
echo -e "   Build Mode: ${BUILD_MODE}"
echo -e "   Log Level: ${LOG_LEVEL}"

# 检查二进制文件
BINARY_PATH="target/${BUILD_MODE}/analytics-server"
if [[ ! -f "${BINARY_PATH}" ]]; then
    echo -e "${RED}❌ Binary not found: ${BINARY_PATH}${NC}"
    echo -e "${YELLOW}💡 Please run ./scripts/build.sh first${NC}"
    exit 1
fi

# 设置环境变量
export RUST_LOG=${LOG_LEVEL}
export ANALYTICS_LISTEN_ADDR=${LISTEN_ADDR}
if [[ -n "${SOCKET_PATH}" ]]; then
    export ANALYTICS_SOCKET_PATH=${SOCKET_PATH}
fi

# 设置Python环境（如果启用Python桥接）
export PYTHONPATH="${PWD}/python:${PYTHONPATH}"

# 启动服务器
echo -e "${GREEN}🎯 Starting server...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

exec "${BINARY_PATH}" 