#!/bin/bash

# 🔍 配置一致性检查脚本
# 目标：确保所有配置文件中的版本、端口、镜像名等保持一致

set -euo pipefail

# 颜色定义
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

echo -e "${BLUE}"
echo "🔍 配置一致性检查"
echo "=================="
echo -e "${NC}"

ISSUES=0

log_error() {
    echo -e "${RED}❌ $1${NC}"
    ((ISSUES++))
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# 检查版本一致性
check_versions() {
    echo ""
    echo -e "${BLUE}📦 版本一致性检查${NC}"
    echo "========================"
    
    # Node.js版本检查
    node_dockerfile=$(grep "FROM node:" web/Dockerfile | grep -o "[0-9]*" | head -1)
    node_ci=$(grep "node-version=" .github/workflows/ci-cd.yml | grep -o "[0-9]*" | head -1)
    node_package=$(grep '"node":' web/package.json | grep -o "[0-9]*" | head -1)
    
    log_info "Node.js版本对比:"
    log_info "  Dockerfile: $node_dockerfile"
    log_info "  CI/CD: $node_ci"
    log_info "  package.json: $node_package"
    
    if [[ "$node_dockerfile" == "$node_ci" && "$node_dockerfile" == "$node_package" ]]; then
        log_success "Node.js版本一致: $node_dockerfile"
    else
        log_error "Node.js版本不一致"
    fi
    
    # Rust版本检查
    rust_dockerfile=$(grep "FROM rust:" backend/Dockerfile | grep -o "[0-9]\+\.[0-9]\+" | head -1)
    rust_ci=$(grep "rust-version=" .github/workflows/ci-cd.yml | grep -o "[0-9]\+\.[0-9]\+" | head -1)
    
    log_info "Rust版本对比:"
    log_info "  Dockerfile: $rust_dockerfile"
    log_info "  CI/CD: $rust_ci"
    
    if [[ "$rust_dockerfile" == "$rust_ci" ]]; then
        log_success "Rust版本一致: $rust_dockerfile"
    else
        log_error "Rust版本不一致"
    fi
}

# 检查端口一致性
check_ports() {
    echo ""
    echo -e "${BLUE}🔌 端口配置检查${NC}"
    echo "========================"
    
    # 后端端口
    backend_dockerfile=$(grep "EXPOSE" backend/Dockerfile | grep -o "[0-9]\+" | head -1)
    backend_compose=$(grep -A 10 "backend:" podman-compose.yml | grep "ports:" -A 3 | grep -o "[0-9]\+:[0-9]\+" | cut -d':' -f1 | head -1)
    backend_env=$(grep "PORT=" backend/Dockerfile | grep -o "[0-9]\+" | head -1)
    
    log_info "后端端口对比:"
    log_info "  Dockerfile EXPOSE: ${backend_dockerfile:-未找到}"
    log_info "  Compose映射: ${backend_compose:-未找到}"
    log_info "  环境变量: ${backend_env:-未找到}"
    
    if [[ -n "$backend_dockerfile" && -n "$backend_compose" && -n "$backend_env" ]]; then
        if [[ "$backend_dockerfile" == "$backend_compose" && "$backend_dockerfile" == "$backend_env" ]]; then
            log_success "后端端口一致: $backend_dockerfile"
        else
            log_error "后端端口不一致"
        fi
    else
        log_warning "无法完全检查后端端口配置"
    fi
    
    # 前端端口
    web_dockerfile=$(grep "EXPOSE" web/Dockerfile | grep -o "[0-9]\+" | head -1)
    web_compose=$(grep -A 10 "web:" podman-compose.yml | grep "ports:" -A 3 | grep -o "[0-9]\+:[0-9]\+" | cut -d':' -f2 | head -1)
    
    log_info "前端端口对比:"
    log_info "  Dockerfile EXPOSE: ${web_dockerfile:-未找到}"
    log_info "  Compose内部端口: ${web_compose:-未找到}"
    
    if [[ -n "$web_dockerfile" && -n "$web_compose" ]]; then
        if [[ "$web_dockerfile" == "$web_compose" ]]; then
            log_success "前端端口一致: $web_dockerfile"
        else
            log_error "前端端口不一致"
        fi
    else
        log_warning "无法完全检查前端端口配置"
    fi
}

# 检查镜像名一致性
check_image_names() {
    echo ""
    echo -e "${BLUE}🏷️ 镜像名称检查${NC}"
    echo "========================"
    
    # 从CI配置提取镜像基础名称
    backend_base_ci=$(grep "BACKEND_IMAGE_BASE" .github/workflows/ci-cd.yml | grep -o "ghcr.io[^']*" | head -1)
    web_base_ci=$(grep "WEB_IMAGE_BASE" .github/workflows/ci-cd.yml | grep -o "ghcr.io[^']*" | head -1)
    
    # 从Compose配置提取默认镜像名称
    backend_default_compose=$(grep "BACKEND_IMAGE:-" podman-compose.yml | grep -o "ghcr.io[^}]*" | head -1)
    web_default_compose=$(grep "WEB_IMAGE:-" podman-compose.yml | grep -o "ghcr.io[^}]*" | head -1)
    
    log_info "镜像名称对比:"
    log_info "  CI后端基础: $backend_base_ci"
    log_info "  Compose后端默认: $backend_default_compose"
    
    if [[ "$backend_base_ci" == "${backend_default_compose%:*}" ]]; then
        log_success "后端镜像名称一致"
    else
        log_warning "后端镜像名称可能不一致"
    fi
    
    log_info "  CI前端基础: $web_base_ci"
    log_info "  Compose前端默认: $web_default_compose"
    
    if [[ "$web_base_ci" == "${web_default_compose%:*}" ]]; then
        log_success "前端镜像名称一致"
    else
        log_warning "前端镜像名称可能不一致"
    fi
}

# 检查二进制文件名一致性
check_binary_names() {
    echo ""
    echo -e "${BLUE}📦 二进制文件名检查${NC}"
    echo "========================"
    
    # 从Cargo.toml获取二进制名称
    cargo_bin_name=$(grep -A 2 "\[\[bin\]\]" backend/Cargo.toml | grep "name" | grep -o '"[^"]*"' | tr -d '"')
    
    # 从Dockerfile获取复制的二进制名称
    dockerfile_bin_source=$(grep "cp target.*release/" backend/Dockerfile | grep -o "release/[^[:space:]]*" | cut -d'/' -f2)
    dockerfile_bin_dest=$(grep "cp target.*release/" backend/Dockerfile | grep -o "/build/[^[:space:]]*" | cut -d'/' -f3)
    
    log_info "二进制文件名对比:"
    log_info "  Cargo.toml定义: $cargo_bin_name"
    log_info "  Dockerfile源文件: $dockerfile_bin_source"
    log_info "  Dockerfile目标文件: $dockerfile_bin_dest"
    
    if [[ "$cargo_bin_name" == "$dockerfile_bin_source" ]]; then
        log_success "二进制文件名一致: $cargo_bin_name"
    else
        log_error "二进制文件名不一致"
    fi
}

# 检查健康检查配置
check_healthcheck() {
    echo ""
    echo -e "${BLUE}🏥 健康检查配置${NC}"
    echo "========================"
    
    # 检查Dockerfile中的健康检查
    backend_health_dockerfile=$(grep -A 1 "HEALTHCHECK" backend/Dockerfile | grep "CMD" | grep -o "localhost:[0-9]\+" | grep -o "[0-9]\+" || echo "")
    web_health_dockerfile=$(grep -A 1 "HEALTHCHECK" web/Dockerfile | grep "CMD" | grep -o "localhost:[0-9]\+" | grep -o "[0-9]\+" || echo "")
    
    # 检查Compose中的健康检查
    backend_health_compose=$(grep -A 3 "backend:" -A 20 podman-compose.yml | grep "localhost:[0-9]\+" | grep -o "[0-9]\+" | head -1 || echo "")
    web_health_compose=$(grep -A 3 "web:" -A 20 podman-compose.yml | grep "localhost:[0-9]\+" | grep -o "[0-9]\+" | head -1 || echo "")
    
    log_info "健康检查端口对比:"
    log_info "  后端Dockerfile: $backend_health_dockerfile"
    log_info "  后端Compose: $backend_health_compose"
    
    if [[ "$backend_health_dockerfile" == "$backend_health_compose" ]]; then
        log_success "后端健康检查端口一致"
    else
        log_warning "后端健康检查端口可能不一致"
    fi
    
    log_info "  前端Dockerfile: $web_health_dockerfile"
    log_info "  前端Compose: $web_health_compose"
    
    if [[ "$web_health_dockerfile" == "$web_health_compose" ]]; then
        log_success "前端健康检查端口一致"
    else
        log_warning "前端健康检查端口可能不一致"
    fi
}

# 主函数
main() {
    check_versions
    check_ports
    check_image_names
    check_binary_names
    check_healthcheck
    
    echo ""
    echo -e "${BLUE}📊 检查结果总结${NC}"
    echo "========================"
    echo "发现问题数量: $ISSUES"
    
    if [ $ISSUES -eq 0 ]; then
        echo -e "${GREEN}"
        echo "🎉 所有配置检查通过！"
        echo "✅ 配置文件之间保持一致"
        echo "🚀 可以安全进行构建和部署"
        echo -e "${NC}"
        exit 0
    else
        echo -e "${RED}"
        echo "❌ 发现 $ISSUES 个配置不一致问题"
        echo "🚨 请修复配置不一致问题"
        echo ""
        echo "💡 修复建议:"
        echo "  1. 检查版本号是否在所有文件中保持一致"
        echo "  2. 确认端口映射配置正确"
        echo "  3. 验证镜像名称和标签设置"
        echo "  4. 检查二进制文件名匹配"
        echo -e "${NC}"
        exit 1
    fi
}

# 执行主函数
main "$@" 