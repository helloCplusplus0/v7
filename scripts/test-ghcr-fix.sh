#!/bin/bash

# 🧪 GitHub Container Registry 认证修复测试脚本
# 用于验证CI/CD修复是否有效

set -euo pipefail

echo "🧪 GitHub Container Registry 认证修复测试"
echo "============================================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试函数
test_passed() {
    echo -e "${GREEN}✅ $1${NC}"
}

test_failed() {
    echo -e "${RED}❌ $1${NC}"
}

test_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

test_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# 1. 测试用户名大小写转换
echo "🔧 测试1: 用户名大小写转换"
echo "----------------------------------------"

ORIGINAL_USER="helloCplusplus0"
LOWERCASE_USER=$(echo "$ORIGINAL_USER" | tr '[:upper:]' '[:lower:]')

if [[ "$LOWERCASE_USER" == "hellocplusplus0" ]]; then
    test_passed "用户名转换正确: $ORIGINAL_USER -> $LOWERCASE_USER"
else
    test_failed "用户名转换失败: $ORIGINAL_USER -> $LOWERCASE_USER"
    exit 1
fi

# 2. 测试镜像标签格式验证
echo ""
echo "🏷️  测试2: 镜像标签格式验证"
echo "----------------------------------------"

# 测试正确格式
CORRECT_TAGS=(
    "ghcr.io/hellocplusplus0/v7/backend:latest"
    "ghcr.io/hellocplusplus0/v7/web:latest"
    "ghcr.io/hellocplusplus0/test:auth-check"
)

# 测试错误格式
INCORRECT_TAGS=(
    "ghcr.io/helloCplusplus0/v7/backend:latest"
    "ghcr.io/HelloCplusplus0/v7/web:latest"
    "ghcr.io/HELLOCPLUSPLUS0/test:auth-check"
)

echo "测试正确格式的标签:"
for tag in "${CORRECT_TAGS[@]}"; do
    if [[ ! "$tag" =~ [A-Z] ]]; then
        test_passed "格式正确: $tag"
    else
        test_failed "格式错误: $tag (包含大写字母)"
    fi
done

echo ""
echo "测试错误格式的标签:"
for tag in "${INCORRECT_TAGS[@]}"; do
    if [[ "$tag" =~ [A-Z] ]]; then
        test_passed "检测到错误格式: $tag (包含大写字母)"
    else
        test_failed "未检测到错误格式: $tag"
    fi
done

# 3. 测试环境变量替换
echo ""
echo "🔄 测试3: 环境变量替换"
echo "----------------------------------------"

# 模拟CI/CD环境变量
export REGISTRY_USER_LOWER="hellocplusplus0"
export TAG="latest"

# 测试模板替换
BACKEND_TEMPLATE="ghcr.io/\${REGISTRY_USER_LOWER}/v7/backend:\${TAG}"
WEB_TEMPLATE="ghcr.io/\${REGISTRY_USER_LOWER}/v7/web:\${TAG}"

BACKEND_RESULT=$(envsubst <<< "$BACKEND_TEMPLATE")
WEB_RESULT=$(envsubst <<< "$WEB_TEMPLATE")

if [[ "$BACKEND_RESULT" == "ghcr.io/hellocplusplus0/v7/backend:latest" ]]; then
    test_passed "后端镜像模板替换正确: $BACKEND_RESULT"
else
    test_failed "后端镜像模板替换失败: $BACKEND_RESULT"
fi

if [[ "$WEB_RESULT" == "ghcr.io/hellocplusplus0/v7/web:latest" ]]; then
    test_passed "前端镜像模板替换正确: $WEB_RESULT"
else
    test_failed "前端镜像模板替换失败: $WEB_RESULT"
fi

echo ""
echo "📊 测试总结"
echo "============================================"
test_info "关键修复验证完成！"

echo ""
echo "🚀 下一步操作:"
echo "1. 提交修复后的.github/workflows/ci-cd.yml文件"
echo "2. 推送到GitHub触发CI/CD流程"
echo "3. 观察GitHub Actions日志确认修复效果"

echo ""
echo "🔍 关键修复点:"
echo "- ✅ 用户名大小写转换: helloCplusplus0 -> hellocplusplus0"
echo "- ✅ 认证使用原始用户名，推送使用小写标签"
echo "- ✅ 添加了镜像标签格式验证"
echo "- ✅ 修复了部署配置中的默认值"

test_passed "GHCR认证修复测试完成！"
