#!/bin/bash

# 🧪 GitHub Actions 变量传递测试脚本
# 用于模拟和验证 GitHub Actions 中的变量传递问题

set -euo pipefail

# 颜色定义
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

echo -e "${BLUE}"
echo "🧪 GitHub Actions 变量传递测试"
echo "================================="
echo -e "${NC}"

# 模拟 GitHub Actions 环境变量
export GITHUB_REF="refs/heads/main"
export GITHUB_REF_NAME="main"
export GITHUB_SHA="97894680013e3401ea78c977b66120e17abf35d2"

echo "🔍 模拟 environment-check 阶段..."

# 模拟镜像标签生成逻辑
if [[ "$GITHUB_REF" == "refs/heads/main" ]]; then
    TAG="latest"
elif [[ "$GITHUB_REF" == "refs/heads/develop" ]]; then
    TAG="develop"
else
    TAG="$GITHUB_REF_NAME"
fi

# 模拟镜像地址生成
BACKEND_BASE="ghcr.io/hellocplusplus0/v7/backend"
WEB_BASE="ghcr.io/hellocplusplus0/v7/web"

BACKEND_IMAGE="${BACKEND_BASE}:${TAG}"
WEB_IMAGE="${WEB_BASE}:${TAG}"

echo "✅ 镜像标签生成结果:"
echo "  分支: $GITHUB_REF"
echo "  标签: $TAG"
echo "  后端镜像: $BACKEND_IMAGE"
echo "  前端镜像: $WEB_IMAGE"

# 模拟 GitHub Actions 输出
echo ""
echo "🔍 模拟 GitHub Actions 输出传递..."
echo "backend-image=$BACKEND_IMAGE"
echo "web-image=$WEB_IMAGE"

# 模拟 deploy-production 阶段
echo ""
echo "🔍 模拟部署阶段 .env.production 生成..."

# 创建测试用的 .env.production 文件
cat > .env.production.test << EOF
# 🐳 容器镜像配置
BACKEND_IMAGE=${BACKEND_IMAGE}
WEB_IMAGE=${WEB_IMAGE}

# 🔧 应用配置
DATABASE_URL=sqlite:./data/prod.db
RUST_LOG=info
NODE_ENV=production

# 🌐 网络配置
BACKEND_PORT=3000
WEB_PORT=8080

# 🏷️ 版本标签
GIT_SHA=${GITHUB_SHA}
BUILD_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
VERSION="${GITHUB_REF_NAME}-${GITHUB_SHA}"
BRANCH_NAME="${GITHUB_REF_NAME}"
COMMIT_SHA="${GITHUB_SHA}"
EOF

echo "📄 生成的 .env.production 文件内容:"
cat .env.production.test

# 模拟部署脚本环境变量加载
echo ""
echo "🔍 模拟部署脚本环境变量加载..."

# 加载环境变量
if [ -f ".env.production.test" ]; then
    echo "📋 加载环境变量文件..."
    set -a  # 自动导出所有变量
    source .env.production.test
    set +a  # 关闭自动导出
    echo "✅ 环境变量加载完成"
    echo "🔍 关键环境变量检查:"
    echo "  - VERSION: ${VERSION:-未设置}"
    echo "  - BACKEND_IMAGE: ${BACKEND_IMAGE:-未设置}"
    echo "  - WEB_IMAGE: ${WEB_IMAGE:-未设置}"
    echo "  - GIT_SHA: ${GIT_SHA:-未设置}"
else
    echo "❌ 未找到 .env.production.test 文件"
    exit 1
fi

# 验证变量是否正确设置
echo ""
echo "🧪 验证结果:"

if [[ -n "${BACKEND_IMAGE:-}" ]]; then
    echo -e "${GREEN}✅ BACKEND_IMAGE 设置正确: $BACKEND_IMAGE${NC}"
else
    echo -e "${RED}❌ BACKEND_IMAGE 未设置或为空${NC}"
fi

if [[ -n "${WEB_IMAGE:-}" ]]; then
    echo -e "${GREEN}✅ WEB_IMAGE 设置正确: $WEB_IMAGE${NC}"
else
    echo -e "${RED}❌ WEB_IMAGE 未设置或为空${NC}"
fi

if [[ -n "${VERSION:-}" ]]; then
    echo -e "${GREEN}✅ VERSION 设置正确: $VERSION${NC}"
else
    echo -e "${RED}❌ VERSION 未设置或为空${NC}"
fi

# 模拟 podman pull 命令
echo ""
echo "🐳 模拟容器镜像拉取命令:"
echo "podman pull \"${BACKEND_IMAGE}\""
echo "podman pull \"${WEB_IMAGE}\""

# 检查镜像标签格式
if [[ "$BACKEND_IMAGE" =~ ^[a-zA-Z0-9._/-]+:[a-zA-Z0-9._-]+$ ]]; then
    echo -e "${GREEN}✅ 后端镜像标签格式正确${NC}"
else
    echo -e "${RED}❌ 后端镜像标签格式错误${NC}"
fi

if [[ "$WEB_IMAGE" =~ ^[a-zA-Z0-9._/-]+:[a-zA-Z0-9._-]+$ ]]; then
    echo -e "${GREEN}✅ 前端镜像标签格式正确${NC}"
else
    echo -e "${RED}❌ 前端镜像标签格式错误${NC}"
fi

# 清理测试文件
rm -f .env.production.test

echo ""
echo "🎯 测试结论:"
echo "  如果所有检查都通过，说明变量传递逻辑正确"
echo "  如果有失败项，需要检查 GitHub Actions 配置"
echo ""
echo "💡 修复建议:"
echo "  1. 确保 environment-check 阶段正确设置输出"
echo "  2. 在部署阶段添加调试信息验证变量值"
echo "  3. 使用默认值作为后备方案" 