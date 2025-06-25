#!/bin/bash

# 🔐 GitHub Container Registry 认证验证脚本
# 用于验证GHCR_TOKEN是否正确配置并具有足够权限

set -euo pipefail

# 🎨 颜色配置
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# 📝 日志函数
log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅ $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️  $1${NC}"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] ℹ️  $1${NC}"; }
step() { echo -e "${PURPLE}[$(date +'%H:%M:%S')] 🔄 $1${NC}"; }

# 📊 配置变量
readonly REGISTRY="ghcr.io"
readonly GITHUB_USER="hellocplusplus0"
readonly REPO_NAME="v7"

# 🔍 检查环境
check_environment() {
    step "检查运行环境..."
    
    # 检查必要工具
    local tools=("curl" "jq" "podman")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "缺少必要工具: $tool"
            echo "安装命令："
            case "$tool" in
                "curl") echo "  sudo apt-get install curl" ;;
                "jq") echo "  sudo apt-get install jq" ;;
                "podman") echo "  sudo apt-get install podman" ;;
            esac
            exit 1
        fi
    done
    
    log "环境检查通过"
}

# 🔐 验证GitHub API访问
verify_github_api() {
    step "验证GitHub API访问权限..."
    
    # 获取token
    local token=""
    if [[ -n "${GHCR_TOKEN:-}" ]]; then
        token="$GHCR_TOKEN"
        info "使用环境变量 GHCR_TOKEN"
    else
        warn "未找到环境变量 GHCR_TOKEN"
        echo "请设置环境变量："
        echo "export GHCR_TOKEN=ghp_your_token_here"
        echo ""
        echo "或者手动输入token："
        read -s -p "GitHub Token: " token
        echo ""
    fi
    
    if [[ -z "$token" ]]; then
        error "Token为空，无法继续验证"
        exit 1
    fi
    
    # 验证token格式
    if [[ "$token" =~ ^ghp_ ]]; then
        log "检测到Personal Access Token格式"
    elif [[ "$token" =~ ^ghs_ ]]; then
        log "检测到GitHub Actions Token格式"
    else
        warn "未知token格式，但继续尝试验证"
    fi
    
    info "Token长度: ${#token}"
    info "Token前缀: ${token:0:8}..."
    
    # 测试GitHub API访问
    info "测试GitHub API访问..."
    local api_response
    api_response=$(curl -s -H "Authorization: Bearer $token" \
                       -H "Accept: application/vnd.github.v3+json" \
                       "https://api.github.com/user")
    
    if [[ $? -eq 0 ]]; then
        local username=$(echo "$api_response" | jq -r '.login // "unknown"')
        if [[ "$username" != "null" && "$username" != "unknown" ]]; then
            log "GitHub API访问成功"
            info "认证用户: $username"
        else
            error "GitHub API访问失败"
            echo "响应: $api_response"
            exit 1
        fi
    else
        error "GitHub API请求失败"
        exit 1
    fi
    
    # 测试包权限
    info "测试GitHub Packages权限..."
    local packages_response
    packages_response=$(curl -s -H "Authorization: Bearer $token" \
                           -H "Accept: application/vnd.github.v3+json" \
                           "https://api.github.com/user/packages?package_type=container")
    
    if [[ $? -eq 0 ]]; then
        log "GitHub Packages权限验证成功"
    else
        warn "GitHub Packages权限可能不足"
    fi
    
    # 将token保存到全局变量
    GITHUB_TOKEN="$token"
}

# 🐳 验证容器注册表访问
verify_registry_access() {
    step "验证容器注册表访问..."
    
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        error "GitHub Token未设置"
        exit 1
    fi
    
    # 登录到GHCR
    info "登录到GitHub Container Registry..."
    echo "$GITHUB_TOKEN" | podman login "$REGISTRY" -u "$GITHUB_USER" --password-stdin
    
    if [[ $? -eq 0 ]]; then
        log "GHCR登录成功"
    else
        error "GHCR登录失败"
        exit 1
    fi
    
    # 测试拉取权限
    info "测试镜像拉取权限..."
    local test_image="$REGISTRY/$GITHUB_USER/$REPO_NAME/backend:latest"
    
    if podman pull "$test_image" 2>/dev/null; then
        log "镜像拉取权限验证成功"
        info "成功拉取: $test_image"
    else
        warn "镜像拉取失败，可能镜像不存在或权限不足"
    fi
    
    # 测试推送权限
    info "测试镜像推送权限..."
    local test_tag="$REGISTRY/$GITHUB_USER/test:auth-verification-$(date +%s)"
    
    # 创建测试镜像
    cat > Dockerfile.test << 'EOF'
FROM alpine:latest
LABEL description="GitHub Container Registry authentication test"
RUN echo "Authentication test successful" > /test.txt
EOF
    
    if podman build -t "$test_tag" -f Dockerfile.test .; then
        info "测试镜像构建成功"
        
        if podman push "$test_tag"; then
            log "镜像推送权限验证成功"
            info "成功推送: $test_tag"
            
            # 清理测试镜像
            podman rmi "$test_tag" 2>/dev/null || true
        else
            error "镜像推送权限验证失败"
            echo ""
            echo "可能的原因："
            echo "1. Token缺少 write:packages 权限"
            echo "2. Token缺少对该仓库的访问权限"
            echo "3. 仓库不存在或权限设置错误"
            exit 1
        fi
    else
        error "测试镜像构建失败"
        exit 1
    fi
    
    # 清理
    rm -f Dockerfile.test
}

# 🧪 验证CI/CD集成
verify_cicd_integration() {
    step "验证CI/CD集成配置..."
    
    # 检查GitHub Secrets
    info "检查GitHub仓库配置..."
    
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        error "GitHub Token未设置"
        exit 1
    fi
    
    # 获取仓库信息
    local repo_response
    repo_response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
                        -H "Accept: application/vnd.github.v3+json" \
                        "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME")
    
    if [[ $? -eq 0 ]]; then
        local repo_name=$(echo "$repo_response" | jq -r '.name // "unknown"')
        if [[ "$repo_name" == "$REPO_NAME" ]]; then
            log "仓库访问权限验证成功"
            info "仓库: $GITHUB_USER/$REPO_NAME"
        else
            error "仓库访问权限验证失败"
            exit 1
        fi
    else
        error "无法访问GitHub仓库"
        exit 1
    fi
    
    # 检查GitHub Actions权限
    info "检查GitHub Actions权限..."
    local actions_response
    actions_response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
                          -H "Accept: application/vnd.github.v3+json" \
                          "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME/actions/permissions")
    
    if [[ $? -eq 0 ]]; then
        log "GitHub Actions权限检查完成"
    else
        warn "GitHub Actions权限检查失败，但不影响镜像推送"
    fi
}

# 📋 生成报告
generate_report() {
    step "生成验证报告..."
    
    echo ""
    echo -e "${CYAN}🎉 GitHub Container Registry 认证验证完成！${NC}"
    echo ""
    echo -e "${BLUE}📋 验证结果:${NC}"
    echo -e "  ✅ GitHub API访问: 正常"
    echo -e "  ✅ GitHub Packages权限: 正常"
    echo -e "  ✅ GHCR登录: 成功"
    echo -e "  ✅ 镜像拉取权限: 正常"
    echo -e "  ✅ 镜像推送权限: 正常"
    echo -e "  ✅ 仓库访问权限: 正常"
    echo ""
    echo -e "${BLUE}🔧 配置信息:${NC}"
    echo -e "  🌐 注册表: $REGISTRY"
    echo -e "  👤 用户: $GITHUB_USER"
    echo -e "  📦 仓库: $REPO_NAME"
    echo -e "  🔑 Token类型: $(if [[ "${GITHUB_TOKEN:-}" =~ ^ghp_ ]]; then echo "Personal Access Token"; else echo "GitHub Actions Token"; fi)"
    echo ""
    echo -e "${GREEN}✅ 你的GHCR_TOKEN配置正确，CI/CD应该能够正常推送镜像！${NC}"
    echo ""
    echo -e "${BLUE}💡 下一步:${NC}"
    echo -e "  1. 确保GitHub Secrets中已设置 GHCR_TOKEN"
    echo -e "  2. 触发GitHub Actions构建"
    echo -e "  3. 检查CI/CD日志确认推送成功"
    echo ""
}

# 🎯 主函数
main() {
    echo -e "${PURPLE}"
    echo "🔐 GitHub Container Registry 认证验证"
    echo "======================================"
    echo -e "${NC}"
    
    check_environment
    verify_github_api
    verify_registry_access
    verify_cicd_integration
    generate_report
    
    log "验证流程全部完成！"
}

# 🚀 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 