#!/bin/bash

# 🔐 GHCR认证测试脚本
# 用于验证GitHub Container Registry认证是否正常工作

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
step() { echo -e "${BLUE}🔧 $1${NC}"; }

# 配置
REGISTRY="ghcr.io"
USERNAME="hellocplusplus0"
BACKEND_IMAGE="ghcr.io/hellocplusplus0/v7/backend:latest"
WEB_IMAGE="ghcr.io/hellocplusplus0/v7/web:latest"

echo "🔐 GHCR认证测试工具"
echo "===================="
echo ""

# 检查podman是否安装
step "检查podman安装状态..."
if ! command -v podman &> /dev/null; then
    error "podman未安装，请先安装podman"
    exit 1
fi
log "podman已安装: $(podman --version)"

# 检查网络连接
step "检查网络连接..."
if curl -f -s --connect-timeout 10 https://ghcr.io/v2/ > /dev/null 2>&1; then
    log "网络连接正常"
else
    warn "GHCR API端点连接异常，但这可能是正常的（需要认证）"
    info "尝试基础连接测试..."
    if curl -I --connect-timeout 10 https://ghcr.io > /dev/null 2>&1; then
        log "基础HTTPS连接正常"
    else
        error "无法连接到ghcr.io，请检查网络"
        exit 1
    fi
fi

# 检查当前认证状态
step "检查当前认证状态..."
if podman login ghcr.io --get-login 2>/dev/null | grep -q "$USERNAME"; then
    log "已经认证到GHCR，用户: $USERNAME"
    ALREADY_AUTHENTICATED=true
else
    warn "尚未认证到GHCR"
    ALREADY_AUTHENTICATED=false
fi

# 测试认证
test_authentication() {
    local token="$1"
    local method="$2"
    
    step "测试认证方式: $method"
    
    if [[ -z "$token" ]]; then
        warn "$method token为空，跳过测试"
        return 1
    fi
    
    # 尝试认证
    if echo "$token" | podman login ghcr.io -u "$USERNAME" --password-stdin 2>/dev/null; then
        log "$method 认证成功"
        
        # 验证认证状态
        if podman login ghcr.io --get-login 2>/dev/null | grep -q "$USERNAME"; then
            log "认证状态验证成功"
            return 0
        else
            error "认证状态验证失败"
            return 1
        fi
    else
        error "$method 认证失败"
        return 1
    fi
}

# 测试镜像拉取
test_image_pull() {
    local image="$1"
    local image_name="$2"
    
    step "测试拉取镜像: $image_name"
    
    # 检查镜像是否存在
    if podman image exists "$image"; then
        info "本地已存在镜像，先删除..."
        podman rmi "$image" 2>/dev/null || true
    fi
    
    # 尝试拉取镜像
    if podman pull "$image" 2>/dev/null; then
        log "$image_name 镜像拉取成功"
        
        # 检查镜像信息
        info "镜像信息:"
        podman inspect "$image" --format "{{.RepoTags}} {{.Created}}" || true
        
        return 0
    else
        error "$image_name 镜像拉取失败"
        return 1
    fi
}

# 主测试流程
main_test() {
    local auth_success=false
    
    echo ""
    step "开始认证测试..."
    
    # 测试GHCR_TOKEN
    if [[ -n "${GHCR_TOKEN:-}" ]]; then
        if test_authentication "$GHCR_TOKEN" "GHCR_TOKEN"; then
            auth_success=true
        fi
    fi
    
    # 测试GITHUB_TOKEN
    if [[ "$auth_success" != "true" && -n "${GITHUB_TOKEN:-}" ]]; then
        if test_authentication "$GITHUB_TOKEN" "GITHUB_TOKEN"; then
            auth_success=true
        fi
    fi
    
    # 检查本地认证
    if [[ "$auth_success" != "true" && "$ALREADY_AUTHENTICATED" == "true" ]]; then
        log "使用现有认证信息"
        auth_success=true
    fi
    
    # 检查token文件
    if [[ "$auth_success" != "true" && -f "$HOME/.ghcr_token" ]]; then
        local file_token=$(cat "$HOME/.ghcr_token" 2>/dev/null || echo "")
        if test_authentication "$file_token" "文件TOKEN"; then
            auth_success=true
        fi
    fi
    
    if [[ "$auth_success" != "true" ]]; then
        error "所有认证方式都失败了"
        echo ""
        echo "🔧 解决方案："
        echo "1. 设置环境变量: export GHCR_TOKEN='your_token'"
        echo "2. 设置环境变量: export GITHUB_TOKEN='your_token'"
        echo "3. 创建token文件: echo 'your_token' > ~/.ghcr_token"
        echo "4. 手动登录: podman login ghcr.io -u $USERNAME"
        echo ""
        echo "📝 获取token方法："
        echo "1. 访问 https://github.com/settings/tokens"
        echo "2. 创建Personal Access Token"
        echo "3. 勾选权限: write:packages, read:packages"
        return 1
    fi
    
    echo ""
    step "开始镜像拉取测试..."
    
    # 测试后端镜像
    test_image_pull "$BACKEND_IMAGE" "后端"
    
    # 测试前端镜像
    test_image_pull "$WEB_IMAGE" "前端"
    
    echo ""
    log "所有测试完成！"
}

# 清理函数
cleanup() {
    step "清理测试镜像..."
    podman rmi "$BACKEND_IMAGE" 2>/dev/null || true
    podman rmi "$WEB_IMAGE" 2>/dev/null || true
    log "清理完成"
}

# 显示帮助
show_help() {
    echo "🔐 GHCR认证测试脚本"
    echo ""
    echo "用法:"
    echo "  $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -c, --cleanup  清理测试镜像"
    echo "  -t, --test     执行认证测试（默认）"
    echo ""
    echo "环境变量:"
    echo "  GHCR_TOKEN     GitHub Container Registry Token"
    echo "  GITHUB_TOKEN   GitHub Personal Access Token"
    echo ""
    echo "示例:"
    echo "  export GITHUB_TOKEN='ghp_xxxxxxxxxxxx'"
    echo "  $0"
    echo ""
    echo "  echo 'ghp_xxxxxxxxxxxx' > ~/.ghcr_token"
    echo "  $0"
}

# 参数处理
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -c|--cleanup)
        cleanup
        exit 0
        ;;
    -t|--test|"")
        main_test
        ;;
    *)
        error "未知参数: $1"
        show_help
        exit 1
        ;;
esac 