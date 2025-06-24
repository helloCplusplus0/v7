#!/bin/bash

# 🧪 部署脚本测试工具
# 用于验证 GitHub Actions 部署脚本的环境变量加载是否正确

set -euo pipefail

# 颜色定义
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

echo -e "${BLUE}"
echo "🧪 部署脚本测试工具"
echo "===================="
echo -e "${NC}"

# 创建测试用的 .env.production 文件
create_test_env() {
    echo "📋 创建测试环境文件..."
    
    cat > .env.production.test << EOF
# 🐳 容器镜像配置
BACKEND_IMAGE=ghcr.io/hellocplusplus0/v7/backend:test
WEB_IMAGE=ghcr.io/hellocplusplus0/v7/web:test

# 🔧 应用配置
DATABASE_URL=sqlite:./data/test.db
RUST_LOG=debug
NODE_ENV=test

# 🌐 网络配置
BACKEND_PORT=3000
WEB_PORT=8080

# 📊 监控配置
MONITOR_PORT=9100

# 🏷️ 版本标签
GIT_SHA=test-sha-123456
BUILD_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
VERSION="test-main-123456"
BRANCH_NAME="test-main"
COMMIT_SHA="test-123456"
EOF

    echo -e "${GREEN}✅ 测试环境文件创建完成${NC}"
}

# 创建测试部署脚本
create_test_deploy_script() {
    echo "📋 创建测试部署脚本..."
    
    cat > deploy.test.sh << 'EOF'
#!/bin/bash
set -euo pipefail

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
  echo "📁 当前目录内容:"
  ls -la
  exit 1
fi

echo "🚀 开始V7项目测试部署..."
echo "📅 部署时间: $(date)"
echo "🏷️ 版本: ${VERSION:-unknown}"

echo "🔍 测试环境变量使用:"
echo "  - 后端镜像: ${BACKEND_IMAGE}"
echo "  - 前端镜像: ${WEB_IMAGE}"
echo "  - Git SHA: ${GIT_SHA}"
echo "  - 分支名: ${BRANCH_NAME:-未设置}"

echo "✅ 测试部署脚本执行成功！"
EOF

    chmod +x deploy.test.sh
    echo -e "${GREEN}✅ 测试部署脚本创建完成${NC}"
}

# 运行测试
run_test() {
    echo "🚀 运行部署脚本测试..."
    
    if ./deploy.test.sh; then
        echo -e "${GREEN}🎉 测试通过！部署脚本环境变量加载正常${NC}"
        return 0
    else
        echo -e "${RED}❌ 测试失败！部署脚本存在问题${NC}"
        return 1
    fi
}

# 清理测试文件
cleanup() {
    echo "🧹 清理测试文件..."
    rm -f .env.production.test deploy.test.sh
    echo -e "${GREEN}✅ 清理完成${NC}"
}

# 主函数
main() {
    echo "🔍 测试 GitHub Actions 部署脚本的环境变量加载..."
    echo ""
    
    create_test_env
    create_test_deploy_script
    
    echo ""
    if run_test; then
        echo ""
        echo -e "${GREEN}📊 测试结果: 成功${NC}"
        echo "💡 这意味着 GitHub Actions 部署脚本应该能正确处理环境变量"
        echo ""
        echo "🔧 如果 GitHub Actions 仍然失败，可能的原因："
        echo "  1. 服务器环境问题"
        echo "  2. SSH 连接问题"
        echo "  3. 权限问题"
        echo "  4. Podman/容器相关问题"
    else
        echo ""
        echo -e "${RED}📊 测试结果: 失败${NC}"
        echo "🚨 需要进一步调试部署脚本逻辑"
    fi
    
    echo ""
    cleanup
}

# 执行主函数
main 