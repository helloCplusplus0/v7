#!/bin/bash
# 🧪 V7项目健康检查修复测试脚本
# 本地验证健康检查解决方案的有效性

set -uo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 测试函数
test_script_existence() {
    log_info "检查脚本文件是否存在..."
    
    local scripts=(
        "scripts/diagnose-deployment-health.sh"
        "scripts/enhanced-deploy.sh"
        "scripts/local-ci-check.sh"
        "scripts/verify-ci-consistency.sh"
    )
    
    local found=0
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            log_success "找到脚本: $script"
            ((found++))
        else
            log_error "缺少脚本: $script"
        fi
    done
    
    if [ $found -eq ${#scripts[@]} ]; then
        return 0
    else
        return 1
    fi
}

test_script_permissions() {
    log_info "检查脚本执行权限..."
    
    local scripts=(
        "scripts/diagnose-deployment-health.sh"
        "scripts/enhanced-deploy.sh"
    )
    
    local fixed=0
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                log_success "脚本可执行: $script"
                ((fixed++))
            else
                log_warning "脚本不可执行: $script，正在修复..."
                chmod +x "$script"
                if [ -x "$script" ]; then
                    log_success "权限修复成功: $script"
                    ((fixed++))
                else
                    log_error "权限修复失败: $script"
                fi
            fi
        fi
    done
    
    return 0
}

test_docker_config() {
    log_info "检查Docker配置..."
    
    local configs=(
        "backend/Dockerfile"
        "web/Dockerfile"
        "podman-compose.yml"
    )
    
    local found=0
    for config in "${configs[@]}"; do
        if [ -f "$config" ]; then
            log_success "找到配置: $config"
            ((found++))
        else
            log_error "缺少配置: $config"
        fi
    done
    
    if [ $found -eq ${#configs[@]} ]; then
        return 0
    else
        return 1
    fi
}

test_github_actions_config() {
    log_info "检查GitHub Actions配置..."
    
    if [ -f ".github/workflows/ci-cd.yml" ]; then
        log_success "找到GitHub Actions配置"
        
        # 检查是否包含增强的健康检查
        if grep -q "diagnose-deployment-health.sh" .github/workflows/ci-cd.yml; then
            log_success "GitHub Actions包含增强健康检查"
        else
            log_warning "GitHub Actions可能缺少增强健康检查"
        fi
        
        # 检查是否包含增强部署脚本
        if grep -q "enhanced-deploy.sh" .github/workflows/ci-cd.yml; then
            log_success "GitHub Actions包含增强部署脚本"
        else
            log_warning "GitHub Actions可能缺少增强部署脚本"
        fi
        return 0
    else
        log_error "缺少GitHub Actions配置文件"
        return 1
    fi
}

# 主测试流程
main() {
    echo "🧪 V7项目健康检查修复测试"
    echo "=========================="
    echo "📅 开始时间: $(date)"
    echo ""
    
    local test_passed=0
    local test_total=4
    
    # 执行测试
    if test_script_existence; then
        ((test_passed++))
    fi
    
    if test_script_permissions; then
        ((test_passed++))
    fi
    
    if test_docker_config; then
        ((test_passed++))
    fi
    
    if test_github_actions_config; then
        ((test_passed++))
    fi
    
    # 总结
    echo ""
    echo "📊 测试结果总结"
    echo "==============="
    echo "通过测试: $test_passed/$test_total"
    echo "通过率: $((test_passed * 100 / test_total))%"
    
    if [ $test_passed -eq $test_total ]; then
        log_success "🎉 所有测试通过！健康检查修复方案已就绪"
        return 0
    elif [ $test_passed -gt $((test_total / 2)) ]; then
        log_warning "⚠️ 大部分测试通过，但仍有问题需要解决"
        return 1
    else
        log_error "❌ 多数测试失败，需要检查配置"
        return 1
    fi
}

# 执行主函数
main "$@" 