#!/bin/bash

# 🔐 GitHub Container Registry 认证测试脚本
# 用于验证PAT token是否具有正确的权限

set -euo pipefail

# 🎨 颜色配置
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# 📝 日志函数
log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅ $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️  $1${NC}"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] ℹ️  $1${NC}"; }

# 📊 配置变量
readonly GITHUB_USER="hellocplusplus0"
readonly REGISTRY="ghcr.io"
readonly TEST_IMAGE="hello-world"
readonly TEST_TAG="ghcr.io/${GITHUB_USER}/test:auth-check"

# 🔍 检查依赖
check_dependencies() {
    info "检查必要工具..."
    
    local tools=("podman" "curl" "jq")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log "$tool 已安装"
        else
            error "$tool 未安装，请先安装: sudo apt install $tool"
            exit 1
        fi
    done
}

# 🔐 获取PAT Token
get_pat_token() {
    info "请输入您的GitHub Personal Access Token (PAT):"
    info "如果还没有创建，请参考: docs/github-container-registry-fix.md"
    echo ""
    
    read -s -p "🔑 PAT Token: " PAT_TOKEN
    echo ""
    
    if [[ -z "$PAT_TOKEN" ]]; then
        error "PAT Token不能为空"
        exit 1
    fi
    
    if [[ ! "$PAT_TOKEN" =~ ^ghp_[A-Za-z0-9]{36}$ ]]; then
        warn "PAT Token格式可能不正确（应该以ghp_开头，长度40字符）"
        read -p "是否继续测试? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 🧪 测试认证
test_authentication() {
    info "测试GitHub Container Registry认证..."
    
    # 登录测试
    if echo "$PAT_TOKEN" | podman login "$REGISTRY" -u "$GITHUB_USER" --password-stdin; then
        log "GHCR登录成功"
    else
        error "GHCR登录失败"
        return 1
    fi
    
    # 检查登录状态
    if podman login "$REGISTRY" --get-login | grep -q "$GITHUB_USER"; then
        log "登录状态验证成功"
    else
        warn "无法验证登录状态"
    fi
}

# 🧪 测试推送权限
test_push_permission() {
    info "测试推送权限..."
    
    # 拉取测试镜像
    if podman pull "$TEST_IMAGE"; then
        log "测试镜像拉取成功"
    else
        error "无法拉取测试镜像"
        return 1
    fi
    
    # 标记镜像
    if podman tag "$TEST_IMAGE" "$TEST_TAG"; then
        log "镜像标记成功"
    else
        error "镜像标记失败"
        return 1
    fi
    
    # 推送测试
    info "尝试推送测试镜像到GHCR..."
    if podman push "$TEST_TAG"; then
        log "✅ 推送权限测试成功！"
        
        # 清理测试镜像
        info "清理测试镜像..."
        podman rmi "$TEST_TAG" 2>/dev/null || true
        podman rmi "$TEST_IMAGE" 2>/dev/null || true
        
        return 0
    else
        error "❌ 推送权限测试失败"
        
        # 清理本地镜像
        podman rmi "$TEST_TAG" 2>/dev/null || true
        podman rmi "$TEST_IMAGE" 2>/dev/null || true
        
        return 1
    fi
}

# 🧪 测试拉取权限
test_pull_permission() {
    info "测试拉取权限..."
    
    # 尝试拉取现有的v7镜像
    local v7_backend="ghcr.io/${GITHUB_USER}/v7/backend:latest"
    local v7_web="ghcr.io/${GITHUB_USER}/v7/web:latest"
    
    for image in "$v7_backend" "$v7_web"; do
        info "测试拉取: $image"
        if podman pull "$image" 2>/dev/null; then
            log "✅ 成功拉取: $image"
            podman rmi "$image" 2>/dev/null || true
        else
            warn "⚠️  无法拉取: $image (可能镜像不存在或权限不足)"
        fi
    done
}

# 🔍 验证token权限
verify_token_scopes() {
    info "验证PAT Token权限范围..."
    
    # 使用GitHub API检查token权限
    local api_response
    if api_response=$(curl -s -H "Authorization: token $PAT_TOKEN" \
                           -H "Accept: application/vnd.github.v3+json" \
                           "https://api.github.com/user"); then
        
        local username
        username=$(echo "$api_response" | jq -r '.login' 2>/dev/null || echo "unknown")
        
        if [[ "$username" == "$GITHUB_USER" ]]; then
            log "✅ Token验证成功，用户: $username"
        else
            warn "⚠️  Token用户名不匹配: 期望 $GITHUB_USER，实际 $username"
        fi
    else
        error "❌ 无法验证token有效性"
        return 1
    fi
    
    # 检查packages权限
    if curl -s -H "Authorization: token $PAT_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/user/packages" > /dev/null; then
        log "✅ Token具有packages访问权限"
    else
        warn "⚠️  Token可能缺少packages权限"
    fi
}

# 📊 生成报告
generate_report() {
    echo ""
    echo -e "${BLUE}📊 认证测试报告${NC}"
    echo "=================================="
    echo "🔗 GitHub用户: $GITHUB_USER"
    echo "🐳 容器注册表: $REGISTRY"
    echo "⏰ 测试时间: $(date)"
    echo ""
    
    if [[ "${AUTH_SUCCESS:-false}" == "true" ]]; then
        echo -e "${GREEN}✅ 认证状态: 成功${NC}"
    else
        echo -e "${RED}❌ 认证状态: 失败${NC}"
    fi
    
    if [[ "${PUSH_SUCCESS:-false}" == "true" ]]; then
        echo -e "${GREEN}✅ 推送权限: 具备${NC}"
    else
        echo -e "${RED}❌ 推送权限: 缺失${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}🔧 建议操作:${NC}"
    
    if [[ "${AUTH_SUCCESS:-false}" != "true" ]]; then
        echo "1. 检查PAT Token是否正确"
        echo "2. 确认token包含以下权限:"
        echo "   - repo"
        echo "   - write:packages"
        echo "   - read:packages"
        echo "3. 参考: docs/github-container-registry-fix.md"
    fi
    
    if [[ "${PUSH_SUCCESS:-false}" != "true" ]]; then
        echo "1. 重新生成PAT Token，确保包含write:packages权限"
        echo "2. 在GitHub仓库Settings中更新GHCR_TOKEN Secret"
        echo "3. 重新运行CI/CD流程"
    fi
    
    if [[ "${AUTH_SUCCESS:-false}" == "true" && "${PUSH_SUCCESS:-false}" == "true" ]]; then
        echo -e "${GREEN}🎉 所有测试通过！您的PAT Token配置正确。${NC}"
        echo ""
        echo "📋 下一步操作:"
        echo "1. 在GitHub仓库Settings → Secrets中添加GHCR_TOKEN"
        echo "2. 将此token值设置为Secret"
        echo "3. 重新运行GitHub Actions工作流"
    fi
}

# 🚀 主函数
main() {
    echo -e "${BLUE}"
    echo "🔐 GitHub Container Registry 认证测试"
    echo "======================================"
    echo -e "${NC}"
    
    check_dependencies
    get_pat_token
    
    # 执行测试
    AUTH_SUCCESS=false
    PUSH_SUCCESS=false
    
    if test_authentication; then
        AUTH_SUCCESS=true
        verify_token_scopes
        test_pull_permission
        
        if test_push_permission; then
            PUSH_SUCCESS=true
        fi
    fi
    
    # 生成报告
    generate_report
    
    # 退出状态
    if [[ "$AUTH_SUCCESS" == "true" && "$PUSH_SUCCESS" == "true" ]]; then
        log "🎉 所有测试通过！"
        exit 0
    else
        error "❌ 部分测试失败，请检查配置"
        exit 1
    fi
}

# 🚀 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 