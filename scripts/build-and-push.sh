#!/bin/bash

# 🚀 V7 本地构建和推送脚本
# 用于在开发环境构建镜像并推送到注册表

set -euo pipefail

# 📋 配置参数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 🎨 输出颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 📝 日志函数
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

# 🔍 检查必要工具
check_requirements() {
    log_info "检查构建环境..."
    
    local required_commands=("podman" "curl" "git")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "缺少必要命令: $cmd"
            exit 1
        fi
    done
    
    # 检查项目结构
    if [[ ! -f "$PROJECT_ROOT/backend/Dockerfile" ]]; then
        log_error "Backend Dockerfile不存在"
        exit 1
    fi
    
    if [[ ! -f "$PROJECT_ROOT/web/Dockerfile" ]]; then
        log_error "Web Dockerfile不存在"
        exit 1
    fi
    
    log_success "环境检查通过"
}

# 🏷️ 生成镜像标签
generate_tags() {
    local registry="${1:-ghcr.io/your-org/v7}"
    local version="${2:-latest}"
    
    # 获取Git信息
    local git_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local git_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    # 根据分支确定版本标签
    case "$git_branch" in
        "main"|"master")
            local tag_suffix="latest"
            ;;
        "develop")
            local tag_suffix="develop"
            ;;
        *)
            local tag_suffix="$git_branch"
            ;;
    esac
    
    # 如果指定了版本，使用指定版本
    if [[ "$version" != "latest" ]]; then
        tag_suffix="$version"
    fi
    
    # 生成镜像标签
    BACKEND_IMAGE="$registry/backend:$tag_suffix"
    WEB_IMAGE="$registry/web:$tag_suffix"
    
    # 附加标签（git commit）
    BACKEND_IMAGE_COMMIT="$registry/backend:$git_commit"
    WEB_IMAGE_COMMIT="$registry/web:$git_commit"
    
    log_info "镜像标签生成:"
    echo "  Backend: $BACKEND_IMAGE"
    echo "  Web: $WEB_IMAGE"
    echo "  Commit标签: $git_commit"
}

# 🦀 构建Backend镜像
build_backend() {
    log_info "构建Backend镜像..."
    
    cd "$PROJECT_ROOT/backend"
    
    # 预构建检查
    if [[ ! -f "Cargo.toml" ]]; then
        log_error "Backend Cargo.toml不存在"
        exit 1
    fi
    
    # 构建镜像
    log_info "开始构建Backend..."
    if podman build \
        --network=host \
        --no-cache \
        -t "$BACKEND_IMAGE" \
        -t "$BACKEND_IMAGE_COMMIT" \
        -f Dockerfile \
        .; then
        log_success "Backend镜像构建成功"
    else
        log_error "Backend镜像构建失败"
        exit 1
    fi
    
    # 显示镜像大小
    local image_size=$(podman images "$BACKEND_IMAGE" --format "{{.Size}}")
    log_info "Backend镜像大小: $image_size"
}

# 🌐 构建Web镜像
build_web() {
    log_info "构建Web镜像..."
    
    cd "$PROJECT_ROOT/web"
    
    # 预构建检查
    if [[ ! -f "package.json" ]]; then
        log_error "Web package.json不存在"
        exit 1
    fi
    
    # 构建镜像
    log_info "开始构建Web..."
    if podman build \
        --network=host \
        --no-cache \
        -t "$WEB_IMAGE" \
        -t "$WEB_IMAGE_COMMIT" \
        -f Dockerfile \
        .; then
        log_success "Web镜像构建成功"
    else
        log_error "Web镜像构建失败"
        exit 1
    fi
    
    # 显示镜像大小
    local image_size=$(podman images "$WEB_IMAGE" --format "{{.Size}}")
    log_info "Web镜像大小: $image_size"
}

# 🔐 登录镜像注册表
login_registry() {
    local registry="${1:-ghcr.io}"
    local username="${2:-}"
    local token="${3:-}"
    
    if [[ -n "$username" && -n "$token" ]]; then
        log_info "登录镜像注册表 $registry..."
        echo "$token" | podman login "$registry" --username "$username" --password-stdin
        log_success "镜像注册表登录成功"
        return 0
    else
        log_warning "未提供注册表凭据"
        log_info "如需推送镜像，请提供用户名和令牌"
        return 1
    fi
}

# 📤 推送镜像
push_images() {
    local push_enabled="$1"
    
    if [[ "$push_enabled" != "true" ]]; then
        log_warning "跳过镜像推送"
        return 0
    fi
    
    log_info "推送镜像到注册表..."
    
    # 推送Backend镜像
    log_info "推送Backend镜像..."
    if podman push "$BACKEND_IMAGE" && podman push "$BACKEND_IMAGE_COMMIT"; then
        log_success "Backend镜像推送成功"
    else
        log_error "Backend镜像推送失败"
        exit 1
    fi
    
    # 推送Web镜像
    log_info "推送Web镜像..."
    if podman push "$WEB_IMAGE" && podman push "$WEB_IMAGE_COMMIT"; then
        log_success "Web镜像推送成功"
    else
        log_error "Web镜像推送失败"
        exit 1
    fi
    
    log_success "所有镜像推送完成"
}

# 📊 构建总结
build_summary() {
    local push_enabled="$1"
    
    log_success "构建完成！"
    echo "========================================"
    echo "🚀 构建信息:"
    echo "  Backend镜像: $BACKEND_IMAGE"
    echo "  Web镜像: $WEB_IMAGE"
    echo "  Commit标签: $(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
    echo "  构建时间: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    
    # 显示镜像列表
    echo "📦 本地镜像:"
    podman images | grep -E "(backend|web)" | head -10
    
    echo ""
    if [[ "$push_enabled" == "true" ]]; then
        echo "🌐 镜像已推送到注册表"
        echo ""
        echo "🚀 远程部署命令:"
        echo "  curl -sSL https://raw.githubusercontent.com/your-org/v7/main/scripts/remote-deploy.sh | bash -s -- \\"
        echo "    -B $BACKEND_IMAGE \\"
        echo "    -W $WEB_IMAGE"
    else
        echo "💾 镜像仅保存在本地"
        echo ""
        echo "📤 如需推送，使用以下命令:"
        echo "  ./build-and-push.sh --push -u <username> -t <token>"
    fi
    echo "========================================"
}

# 🧹 清理旧镜像（可选）
cleanup_old_images() {
    local cleanup_enabled="${1:-false}"
    
    if [[ "$cleanup_enabled" == "true" ]]; then
        log_info "清理未使用的镜像..."
        podman image prune -f
        log_success "镜像清理完成"
    fi
}

# 📋 显示帮助
show_help() {
    cat << 'EOF'
🚀 V7 构建和推送脚本

用法:
    ./build-and-push.sh [选项]

选项:
    -r, --registry URL      镜像注册表地址 (默认: ghcr.io/your-org/v7)
    -v, --version VERSION   镜像版本标签 (默认: 根据Git分支自动生成)
    -u, --username USER     注册表用户名
    -t, --token TOKEN       注册表访问令牌
    -p, --push              推送镜像到注册表
    -c, --cleanup           构建后清理未使用的镜像
    -b, --backend-only      仅构建Backend镜像
    -w, --web-only          仅构建Web镜像
    -h, --help              显示帮助信息

网络配置:
    构建时自动使用 --network=host 参数，适配代理环境
    
示例:
    # 仅构建镜像（不推送）
    ./build-and-push.sh
    
    # 构建并推送镜像
    ./build-and-push.sh --push -u your-username -t your-token
    
    # 构建特定版本
    ./build-and-push.sh -v v1.0.0
    
    # 使用自定义注册表
    ./build-and-push.sh -r registry.your-domain.com/v7
    
    # 仅构建Backend
    ./build-and-push.sh --backend-only
    
    # 构建并清理
    ./build-and-push.sh --cleanup

注意:
    - 确保已安装podman
    - 确保有足够的磁盘空间进行构建
    - 推送镜像需要注册表登录凭据
EOF
}

# 🎯 主函数
main() {
    local registry="ghcr.io/your-org/v7"
    local version="latest"
    local username=""
    local token=""
    local push_enabled="false"
    local cleanup_enabled="false"
    local backend_only="false"
    local web_only="false"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--registry)
                registry="$2"
                shift 2
                ;;
            -v|--version)
                version="$2"
                shift 2
                ;;
            -u|--username)
                username="$2"
                shift 2
                ;;
            -t|--token)
                token="$2"
                shift 2
                ;;
            -p|--push)
                push_enabled="true"
                shift
                ;;
            -c|--cleanup)
                cleanup_enabled="true"
                shift
                ;;
            -b|--backend-only)
                backend_only="true"
                shift
                ;;
            -w|--web-only)
                web_only="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 检查互斥选项
    if [[ "$backend_only" == "true" && "$web_only" == "true" ]]; then
        log_error "不能同时指定 --backend-only 和 --web-only"
        exit 1
    fi
    
    # 如果启用推送但未提供凭据，提示用户
    if [[ "$push_enabled" == "true" && ( -z "$username" || -z "$token" ) ]]; then
        log_warning "启用了推送但未提供完整凭据"
        log_info "可以通过环境变量提供: REGISTRY_USERNAME, REGISTRY_TOKEN"
        
        # 尝试从环境变量获取
        username="${REGISTRY_USERNAME:-$username}"
        token="${REGISTRY_TOKEN:-$token}"
        
        if [[ -z "$username" || -z "$token" ]]; then
            log_error "推送镜像需要用户名和令牌"
            exit 1
        fi
    fi
    
    log_info "开始V7镜像构建..."
    echo "========================================"
    echo "🔧 构建配置:"
    echo "  注册表: $registry"
    echo "  版本: $version"
    echo "  推送: $push_enabled"
    echo "  清理: $cleanup_enabled"
    echo "  仅Backend: $backend_only"
    echo "  仅Web: $web_only"
    echo "========================================"
    
    # 执行构建流程
    check_requirements
    generate_tags "$registry" "$version"
    
    # 如果需要推送，先登录
    if [[ "$push_enabled" == "true" ]]; then
        login_registry "$(echo "$registry" | cut -d'/' -f1)" "$username" "$token"
    fi
    
    # 构建镜像
    if [[ "$web_only" != "true" ]]; then
        build_backend
    fi
    
    if [[ "$backend_only" != "true" ]]; then
        build_web
    fi
    
    # 推送镜像
    push_images "$push_enabled"
    
    # 清理
    cleanup_old_images "$cleanup_enabled"
    
    # 总结
    build_summary "$push_enabled"
}

# 检查是否在项目根目录
cd "$PROJECT_ROOT"

# 运行主函数
main "$@" 