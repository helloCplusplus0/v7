#!/bin/bash

# 🔍 V7项目配置验证脚本
# 验证当前配置的一致性，确保所有历史问题已解决

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
step() { echo -e "${PURPLE}🔧 $1${NC}"; }
check() { echo -e "${CYAN}🔍 $1${NC}"; }

echo "🔍 V7项目配置一致性验证"
echo "=================================="

# 检查计数器
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

check_result() {
    local check_name="$1"
    local result="$2"
    local details="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [[ "$result" == "PASS" ]]; then
        log "$check_name"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        error "$check_name"
        if [[ -n "$details" ]]; then
            echo "   $details"
        fi
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# 1. 检查用户权限配置一致性
step "1. 检查用户权限配置一致性"

# 检查后端Dockerfile
if [[ -f "backend/Dockerfile" ]]; then
    check "检查后端Dockerfile用户配置..."
    if grep -q "adduser -u 1002" backend/Dockerfile; then
        check_result "后端Dockerfile用户ID配置" "PASS"
    else
        check_result "后端Dockerfile用户ID配置" "FAIL" "未找到用户ID 1002配置"
    fi
else
    check_result "后端Dockerfile存在性检查" "FAIL" "backend/Dockerfile不存在"
fi

# 检查前端Dockerfile
if [[ -f "web/Dockerfile" ]]; then
    check "检查前端Dockerfile用户配置..."
    if grep -q "adduser -u 1002" web/Dockerfile; then
        check_result "前端Dockerfile用户ID配置" "PASS"
    else
        check_result "前端Dockerfile用户ID配置" "FAIL" "未找到用户ID 1002配置"
    fi
else
    check_result "前端Dockerfile存在性检查" "FAIL" "web/Dockerfile不存在"
fi

# 检查podman-compose.yml
if [[ -f "podman-compose.yml" ]]; then
    check "检查podman-compose.yml用户配置..."
    if grep -q 'user: "1002:1002"' podman-compose.yml; then
        check_result "podman-compose.yml用户ID配置" "PASS"
    else
        check_result "podman-compose.yml用户ID配置" "FAIL" "未找到用户ID 1002:1002配置"
    fi
else
    check_result "podman-compose.yml存在性检查" "FAIL" "podman-compose.yml不存在"
fi

# 2. 检查CI/CD配置完整性
step "2. 检查CI/CD配置完整性"

if [[ -f ".github/workflows/ci-cd.yml" ]]; then
    check "检查CI/CD工作流配置..."
    
    # 检查镜像标签防空逻辑
    if grep -q "验证输出不为空" .github/workflows/ci-cd.yml; then
        check_result "CI/CD镜像标签防空逻辑" "PASS"
    else
        check_result "CI/CD镜像标签防空逻辑" "FAIL" "未找到镜像标签防空验证"
    fi
    
    # 检查认证配置
    if grep -q "Comprehensive Authentication Check" .github/workflows/ci-cd.yml; then
        check_result "CI/CD认证配置" "PASS"
    else
        check_result "CI/CD认证配置" "FAIL" "未找到全面认证检查"
    fi
    
    # 检查小写转换逻辑
    if grep -q "tr '\[:upper:\]' '\[:lower:\]'" .github/workflows/ci-cd.yml; then
        check_result "CI/CD小写转换逻辑" "PASS"
    else
        check_result "CI/CD小写转换逻辑" "FAIL" "未找到小写转换逻辑"
    fi
    
    # 检查备用逻辑
    if grep -q "备用方法计算小写用户名" .github/workflows/ci-cd.yml; then
        check_result "CI/CD备用逻辑" "PASS"
    else
        check_result "CI/CD备用逻辑" "FAIL" "未找到备用逻辑"
    fi
    
else
    check_result "CI/CD工作流存在性检查" "FAIL" ".github/workflows/ci-cd.yml不存在"
fi

# 3. 检查环境配置
step "3. 检查环境配置"

if [[ -f ".env.production" ]]; then
    check "检查生产环境配置..."
    if grep -q "DATABASE_URL=sqlite:/app/data/prod.db" .env.production; then
        check_result "数据库路径配置" "PASS"
    else
        check_result "数据库路径配置" "FAIL" "数据库路径不是绝对路径"
    fi
else
    check_result "生产环境配置存在性检查" "FAIL" ".env.production不存在"
fi

# 4. 检查脚本权限
step "4. 检查脚本权限"

SCRIPT_FILES=(
    "scripts/deploy.sh"
    "scripts/diagnose-deployment-health.sh"
    "scripts/enhanced-deploy.sh"
    "scripts/start.sh"
)

for script in "${SCRIPT_FILES[@]}"; do
    if [[ -f "$script" ]]; then
        if [[ -x "$script" ]]; then
            check_result "脚本权限检查: $script" "PASS"
        else
            check_result "脚本权限检查: $script" "FAIL" "脚本不可执行"
        fi
    else
        check_result "脚本存在性检查: $script" "FAIL" "脚本不存在"
    fi
done

# 5. 检查GitHub Secrets配置指南
step "5. 检查GitHub Secrets配置指南"

if [[ -f "docs/github-secrets-checklist.md" ]]; then
    check_result "GitHub Secrets配置指南" "PASS"
else
    check_result "GitHub Secrets配置指南" "FAIL" "配置指南缺失"
fi

# 6. 检查历史问题修复文档
step "6. 检查历史问题修复文档"

DOCS_FILES=(
    "docs/DEPLOYMENT_FIXES.md"
    "docs/GHCR_AUTHENTICATION_SOLUTION.md"
    "docs/github-actions-fix-instructions.md"
)

for doc in "${DOCS_FILES[@]}"; do
    if [[ -f "$doc" ]]; then
        check_result "修复文档: $doc" "PASS"
    else
        check_result "修复文档: $doc" "FAIL" "文档缺失"
    fi
done

# 7. 检查关键配置一致性
step "7. 检查关键配置一致性"

check "验证用户ID一致性..."
DOCKERFILE_BACKEND_UID=$(grep -o "adduser -u [0-9]*" backend/Dockerfile 2>/dev/null | grep -o "[0-9]*" || echo "")
DOCKERFILE_WEB_UID=$(grep -o "adduser -u [0-9]*" web/Dockerfile 2>/dev/null | grep -o "[0-9]*" || echo "")
COMPOSE_UID=$(grep -o 'user: "[0-9]*:[0-9]*"' podman-compose.yml 2>/dev/null | grep -o "[0-9]*" | head -1 || echo "")

if [[ "$DOCKERFILE_BACKEND_UID" == "1002" && "$DOCKERFILE_WEB_UID" == "1002" && "$COMPOSE_UID" == "1002" ]]; then
    check_result "用户ID一致性检查" "PASS"
else
    check_result "用户ID一致性检查" "FAIL" "用户ID不一致: Backend=$DOCKERFILE_BACKEND_UID, Web=$DOCKERFILE_WEB_UID, Compose=$COMPOSE_UID"
fi

# 8. 检查镜像标签配置
step "8. 检查镜像标签配置"

if [[ -f ".github/workflows/ci-cd.yml" ]]; then
    # 检查是否有镜像标签验证
    if grep -q "验证镜像标签格式" .github/workflows/ci-cd.yml; then
        check_result "镜像标签格式验证" "PASS"
    else
        check_result "镜像标签格式验证" "FAIL" "缺少镜像标签格式验证"
    fi
    
    # 检查是否有大小写检查
    if grep -q "镜像标签包含大写字母" .github/workflows/ci-cd.yml; then
        check_result "大小写检查逻辑" "PASS"
    else
        check_result "大小写检查逻辑" "FAIL" "缺少大小写检查逻辑"
    fi
fi

# 9. 检查健康检查配置
step "9. 检查健康检查配置"

if [[ -f "podman-compose.yml" ]]; then
    if grep -q "healthcheck:" podman-compose.yml; then
        check_result "健康检查配置" "PASS"
    else
        check_result "健康检查配置" "FAIL" "缺少健康检查配置"
    fi
fi

# 10. 检查监控配置
step "10. 检查监控配置"

if [[ -f "scripts/monitoring.sh" ]]; then
    check_result "监控脚本" "PASS"
else
    check_result "监控脚本" "FAIL" "监控脚本缺失"
fi

# 总结报告
echo ""
echo "📊 配置验证总结"
echo "=================="
echo "总检查项: $TOTAL_CHECKS"
echo "通过: $PASSED_CHECKS"
echo "失败: $FAILED_CHECKS"
echo "成功率: $(( PASSED_CHECKS * 100 / TOTAL_CHECKS ))%"

if [[ $FAILED_CHECKS -eq 0 ]]; then
    log "🎉 所有配置检查通过！项目配置完整且一致。"
    echo ""
    echo "✅ 建议：当前配置已经解决了所有历史问题，建议保持现有CI/CD配置不变。"
    exit 0
else
    error "⚠️ 发现 $FAILED_CHECKS 个配置问题，需要修复。"
    echo ""
    echo "🔧 建议：请根据上述检查结果修复相关配置问题。"
    exit 1
fi 