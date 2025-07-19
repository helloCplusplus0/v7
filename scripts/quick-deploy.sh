#!/bin/bash

# 🚀 V7 快速部署脚本 (修复版)
# 专为远程执行设计，修复了BASH_SOURCE和路径问题

set -euo pipefail

# 📋 配置参数
PROJECT_NAME="v7"
COMPOSE_FILE="podman-compose.yml"
ENV_FILE=".env"

# 🌍 GitHub仓库配置
DEFAULT_REPO_URL="https://github.com/helloCplusplus0/v7.git"
DEFAULT_BRANCH="main"

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

# 🔍 检查必要的命令
check_requirements() {
    log_info "检查部署环境..."
    
    local required_commands=("podman" "podman-compose" "curl" "git")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "缺少必要命令: $cmd"
            log_info "请安装: sudo apt-get install -y $cmd"
            exit 1
        fi
    done
    
    log_success "环境检查通过"
}

# 📦 下载部署配置 (修复版)
download_deployment_config() {
    local repo_url="${1:-$DEFAULT_REPO_URL}"
    local branch="${2:-$DEFAULT_BRANCH}"
    local work_dir="/opt/v7-deploy"
    
    log_info "下载部署配置..."
    log_info "仓库: $repo_url"
    log_info "分支: $branch"
    
    # 清理并创建工作目录
    sudo rm -rf "$work_dir"
    sudo mkdir -p "$work_dir"
    
    # 直接克隆仓库到工作目录
    log_info "克隆仓库..."
    if ! sudo git clone -b "$branch" "$repo_url" "$work_dir" 2>/dev/null; then
        log_error "无法克隆仓库: $repo_url"
        log_error "分支: $branch"
        log_error "请检查仓库地址、分支名称和网络连接"
        exit 1
    fi
    
    # 检查关键文件
    if [[ ! -f "$work_dir/podman-compose.yml" ]]; then
        log_error "未找到podman-compose.yml文件"
        log_error "仓库结构可能不正确"
        exit 1
    fi
    
    # 设置权限
    sudo chown -R "$USER:$USER" "$work_dir"
    
    log_success "部署配置下载完成: $work_dir"
    return 0
}

# 🔧 配置环境变量
setup_environment() {
    local work_dir="$1"
    local backend_image="$2"
    local web_image="$3"
    
    log_info "配置环境变量..."
    
    cd "$work_dir"
    
    # 创建环境配置文件
    cat > "$ENV_FILE" << EOF
# 🚀 V7 生产环境配置
# 自动生成时间: $(date -u +%Y-%m-%dT%H:%M:%SZ)

# ===== 📦 镜像配置 =====
BACKEND_IMAGE=$backend_image
WEB_IMAGE=$web_image

# ===== 🌐 服务配置 =====
# Backend服务
BACKEND_HTTP_PORT=3000
BACKEND_GRPC_PORT=50053

# Web服务  
WEB_PORT=8080

# ===== 🗄️ 数据库配置 =====
DATABASE_URL=sqlite:/app/data/prod.db
ENABLE_PERSISTENCE=true
PERSIST_PATH=/app/data/memory_db.json

# ===== 📊 日志配置 =====
RUST_LOG=info

# ===== 🔐 安全配置 =====
JWT_SECRET=$(openssl rand -base64 32)

# ===== 🧮 Analytics Engine配置 =====
# 默认本地连接 (如需WireGuard,请手动修改)
ANALYTICS_ENGINE_ENDPOINT=http://127.0.0.1:50051
ANALYTICS_CONNECTION_TIMEOUT_SEC=10
ANALYTICS_REQUEST_TIMEOUT_SEC=30
EOF

    log_success "环境配置文件创建完成"
}

# 🔐 登录镜像仓库
login_registry() {
    local registry="$1"
    local username="$2"
    local token="$3"
    
    log_info "登录镜像仓库: $registry"
    
    if echo "$token" | podman login "$registry" --username "$username" --password-stdin; then
        log_success "镜像仓库登录成功"
    else
        log_error "镜像仓库登录失败"
        log_error "请检查用户名和访问令牌"
        exit 1
    fi
}

# 📥 拉取镜像
pull_images() {
    local backend_image="$1"
    local web_image="$2"
    
    log_info "拉取镜像..."
    
    log_info "拉取Backend镜像: $backend_image"
    if ! podman pull "$backend_image"; then
        log_error "Backend镜像拉取失败"
        exit 1
    fi
    
    log_info "拉取Web镜像: $web_image"
    if ! podman pull "$web_image"; then
        log_error "Web镜像拉取失败"
        exit 1
    fi
    
    log_success "镜像拉取完成"
}

# 🛑 停止现有服务
stop_existing_services() {
    local work_dir="$1"
    
    log_info "停止现有服务..."
    
    cd "$work_dir"
    
    # 尝试停止服务 (允许失败)
    podman-compose down 2>/dev/null || true
    
    # 清理悬空容器
    podman container prune -f 2>/dev/null || true
    
    log_success "现有服务已停止"
}

# 🚀 启动服务
start_services() {
    local work_dir="$1"
    
    log_info "启动V7服务..."
    
    cd "$work_dir"
    
    # 启动服务
    if podman-compose up -d; then
        log_success "服务启动完成"
    else
        log_error "服务启动失败"
        log_error "请检查podman-compose.yml配置"
        exit 1
    fi
}

# 🏥 健康检查
health_check() {
    local work_dir="$1"
    
    log_info "执行健康检查..."
    
    # 等待服务启动
    sleep 10
    
    # 检查backend健康状态
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "健康检查尝试 $attempt/$max_attempts"
        
        if curl -f http://localhost:3000/health >/dev/null 2>&1; then
            log_success "Backend服务健康检查通过"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Backend服务健康检查失败"
            return 1
        fi
        
        sleep 5
        ((attempt++))
    done
    
    # 检查web服务
    if curl -f http://localhost:8080/ >/dev/null 2>&1; then
        log_success "Web服务健康检查通过"
    else
        log_warning "Web服务可能未完全启动，请稍后检查"
    fi
    
    return 0
}

# 📊 部署总结
deployment_summary() {
    local work_dir="$1"
    local backend_image="$2"
    local web_image="$3"
    
    log_success "🎉 V7部署完成！"
    
    echo "========================================"
    echo "🚀 部署信息:"
    echo "  工作目录: $work_dir"
    echo "  Backend镜像: $backend_image"
    echo "  Web镜像: $web_image"
    echo "  部署时间: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    echo "🌐 访问地址:"
    echo "  Backend API: http://localhost:3000"
    echo "  Backend Health: http://localhost:3000/health"
    echo "  Web应用: http://localhost:8080"
    echo ""
    echo "🔧 管理命令:"
    echo "  查看状态: cd $work_dir && podman-compose ps"
    echo "  查看日志: cd $work_dir && podman-compose logs -f"
    echo "  重启服务: cd $work_dir && podman-compose restart"
    echo "  停止服务: cd $work_dir && podman-compose down"
    echo "========================================"
}

# 📋 显示帮助
show_help() {
    cat << 'EOF'
🚀 V7 快速部署脚本 (修复版)

用法:
    curl -sSL https://raw.githubusercontent.com/helloCplusplus0/v7/main/scripts/quick-deploy.sh | bash -s -- [选项]

选项:
    -B, --backend IMAGE     Backend镜像地址
    -W, --web IMAGE         Web镜像地址  
    -u, --username USER     注册表用户名
    -t, --token TOKEN       注册表访问令牌
    -r, --repo URL          Git仓库地址 (可选)
    -b, --branch BRANCH     Git分支 (可选)
    -h, --help              显示帮助信息

示例:
    curl -sSL https://raw.githubusercontent.com/helloCplusplus0/v7/main/scripts/quick-deploy.sh | bash -s -- \
        -B ghcr.io/hellocplusplus0/v7/backend:latest \
        -W ghcr.io/hellocplusplus0/v7/web:latest \
        -u helloCplusplus0 \
        -t your-token

注意:
    - 确保服务器已安装 podman, podman-compose, curl, git
    - 确保防火墙开放3000和8080端口
    - 部署完成后请及时修改JWT_SECRET
EOF
}

# 🎯 主函数
main() {
    # 显示横幅
    echo "🚀 V7快速部署系统 (修复版)"
    echo "========================================"
    
    # 默认参数
    local backend_image=""
    local web_image=""
    local username=""
    local token=""
    local repo_url="$DEFAULT_REPO_URL"
    local branch="$DEFAULT_BRANCH"
    local work_dir=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -B|--backend)
                backend_image="$2"
                shift 2
                ;;
            -W|--web)
                web_image="$2"
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
            -r|--repo)
                repo_url="$2"
                shift 2
                ;;
            -b|--branch)
                branch="$2"
                shift 2
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
    
    # 验证必需参数
    if [[ -z "$backend_image" || -z "$web_image" || -z "$username" || -z "$token" ]]; then
        log_error "缺少必需参数"
        show_help
        exit 1
    fi
    
    # 显示配置信息
    log_info "开始V7应用部署..."
    echo "========================================"
    echo "📦 部署配置:"
    echo "  仓库: $repo_url"
    echo "  分支: $branch"
    echo "  Backend镜像: $backend_image"
    echo "  Web镜像: $web_image"
    echo "========================================"
    
    # 执行部署流程
    check_requirements
    
    work_dir="/opt/v7-deploy"
    download_deployment_config "$repo_url" "$branch"
    setup_environment "$work_dir" "$backend_image" "$web_image"
    login_registry "ghcr.io" "$username" "$token"
    pull_images "$backend_image" "$web_image"
    stop_existing_services "$work_dir"
    start_services "$work_dir"
    
    if health_check "$work_dir"; then
        deployment_summary "$work_dir" "$backend_image" "$web_image"
    else
        log_error "部署失败，请检查日志"
        log_info "调试命令: cd $work_dir && podman-compose logs"
        exit 1
    fi
}

# 🚀 执行主函数
main "$@" 