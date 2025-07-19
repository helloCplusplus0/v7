#!/bin/bash

# 🚀 V7 远程部署脚本 - 轻量化版本
# 用于在云服务器上自动拉取镜像并部署v7应用

set -euo pipefail

# 📋 配置参数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="v7"
COMPOSE_FILE="podman-compose.yml"
ENV_FILE=".env"

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

# 📦 下载部署配置
download_deployment_config() {
    local repo_url="${1:-https://github.com/your-org/v7.git}"
    local branch="${2:-main}"
    local temp_dir="/tmp/v7-deploy-$(date +%s)"
    
    log_info "下载部署配置..."
    
    # 创建临时目录
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # 使用sparse-checkout只下载必要文件
    git init
    git remote add origin "$repo_url"
    git config core.sparseCheckout true
    
    # 只下载部署相关文件
    cat > .git/info/sparse-checkout << 'EOF'
podman-compose.yml
compose.env.example
scripts/
backend/Dockerfile
web/Dockerfile
WIREGUARD_DEPLOYMENT_GUIDE.md
EOF
    
    git pull origin "$branch"
    
    # 复制文件到工作目录
    local work_dir="/opt/v7-deploy"
    sudo mkdir -p "$work_dir"
    sudo cp -r * "$work_dir/"
    sudo chown -R "$USER:$USER" "$work_dir"
    
    cd "$work_dir"
    rm -rf "$temp_dir"
    
    log_success "部署配置下载完成: $work_dir"
    echo "$work_dir"
}

# 🔧 配置环境变量
setup_environment() {
    local work_dir="$1"
    local backend_image="${2:-ghcr.io/your-org/v7/backend:latest}"
    local web_image="${3:-ghcr.io/your-org/v7/web:latest}"
    
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

# ===== 🧮 Analytics Engine =====
# 生产环境：通过WireGuard VPN连接本地analytics-engine
ANALYTICS_ENGINE_ENDPOINT=http://10.0.0.1:50051
ANALYTICS_CONNECTION_TIMEOUT_SEC=10
ANALYTICS_REQUEST_TIMEOUT_SEC=30

# ===== 🗄️ 数据库配置 =====
DATABASE_URL=sqlite:/app/data/prod.db
ENABLE_PERSISTENCE=true
PERSIST_PATH=/app/data/memory_db.json

# ===== 📊 运行环境 =====
NODE_ENV=production
RUST_LOG=info
RUST_BACKTRACE=1

# ===== 🔐 安全配置 =====
JWT_SECRET=$(openssl rand -hex 32)
EOF
    
    log_success "环境配置完成"
}

# 🔐 登录镜像注册表
login_registry() {
    local registry="${1:-ghcr.io}"
    local username="${2:-}"
    local token="${3:-}"
    
    if [[ -n "$username" && -n "$token" ]]; then
        log_info "登录镜像注册表..."
        echo "$token" | podman login "$registry" --username "$username" --password-stdin
        log_success "镜像注册表登录成功"
    else
        log_warning "未提供注册表凭据，尝试使用匿名访问..."
    fi
}

# 📦 拉取镜像
pull_images() {
    local backend_image="$1"
    local web_image="$2"
    
    log_info "拉取应用镜像..."
    
    # 拉取backend镜像
    log_info "拉取Backend镜像: $backend_image"
    if podman pull "$backend_image"; then
        log_success "Backend镜像拉取成功"
    else
        log_error "Backend镜像拉取失败"
        exit 1
    fi
    
    # 拉取web镜像
    log_info "拉取Web镜像: $web_image"
    if podman pull "$web_image"; then
        log_success "Web镜像拉取成功"
    else
        log_error "Web镜像拉取失败"
        exit 1
    fi
    
    # 显示镜像信息
    log_info "镜像信息:"
    podman images | grep -E "(backend|web)" | head -5
}

# 🛑 停止现有服务
stop_existing_services() {
    local work_dir="$1"
    
    log_info "停止现有服务..."
    
    cd "$work_dir"
    
    # 停止容器服务
    if [[ -f "$COMPOSE_FILE" ]]; then
        podman-compose down || true
        log_success "容器服务已停止"
    fi
    
    # 清理未使用的镜像（可选，节省空间）
    podman image prune -f || true
}

# 🚀 启动服务
start_services() {
    local work_dir="$1"
    
    log_info "启动V7服务..."
    
    cd "$work_dir"
    
    # 创建必要目录
    mkdir -p data logs
    
    # 启动容器服务
    if podman-compose up -d; then
        log_success "容器服务启动成功"
    else
        log_error "容器服务启动失败"
        log_info "查看详细日志:"
        podman-compose logs
        exit 1
    fi
}

# 🔍 健康检查
health_check() {
    local work_dir="$1"
    local max_retries=30
    local retry_interval=10
    
    log_info "执行健康检查..."
    
    cd "$work_dir"
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 20
    
    # Backend健康检查
    log_info "检查Backend服务..."
    for ((i=1; i<=max_retries; i++)); do
        if curl -f http://localhost:3000/health > /dev/null 2>&1; then
            log_success "Backend服务正常"
            break
        else
            if [[ $i -eq $max_retries ]]; then
                log_error "Backend健康检查失败"
                log_info "Backend日志:"
                podman logs v7-backend --tail=20
                return 1
            fi
            log_warning "Backend检查失败，重试 $i/$max_retries..."
            sleep $retry_interval
        fi
    done
    
    # Web健康检查
    log_info "检查Web服务..."
    for ((i=1; i<=max_retries; i++)); do
        if curl -f http://localhost:8080 > /dev/null 2>&1; then
            log_success "Web服务正常"
            break
        else
            if [[ $i -eq $max_retries ]]; then
                log_error "Web健康检查失败"
                log_info "Web日志:"
                podman logs v7-web --tail=20
                return 1
            fi
            log_warning "Web检查失败，重试 $i/$max_retries..."
            sleep $retry_interval
        fi
    done
    
    # 显示服务状态
    log_info "服务状态:"
    podman-compose ps
    
    # 显示资源使用情况
    log_info "资源使用:"
    podman stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
    
    log_success "所有服务健康检查通过"
}

# 📊 部署总结
deployment_summary() {
    local work_dir="$1"
    local backend_image="$2"
    local web_image="$3"
    
    log_success "V7应用部署完成！"
    echo "========================================"
    echo "🚀 部署信息:"
    echo "  工作目录: $work_dir"
    echo "  Backend镜像: $backend_image"
    echo "  Web镜像: $web_image"
    echo "  部署时间: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    echo "🌐 访问地址:"
    echo "  Web应用: http://$(hostname -I | awk '{print $1}'):8080"
    echo "  Backend API: http://$(hostname -I | awk '{print $1}'):3000"
    echo ""
    echo "🔧 管理命令:"
    echo "  查看状态: cd $work_dir && podman-compose ps"
    echo "  查看日志: cd $work_dir && podman-compose logs -f"
    echo "  重启服务: cd $work_dir && podman-compose restart"
    echo "  停止服务: cd $work_dir && podman-compose down"
    echo ""
    echo "📊 系统资源:"
    free -h | head -2
    df -h / | tail -1
    echo "========================================"
}

# 🔧 命令行参数处理
show_help() {
    cat << 'EOF'
🚀 V7 远程部署脚本

用法:
    ./remote-deploy.sh [选项]

选项:
    -r, --repo URL          Git仓库地址
    -b, --branch NAME       分支名称 (默认: main)
    -B, --backend IMAGE     Backend镜像地址
    -W, --web IMAGE         Web镜像地址
    -u, --username USER     镜像注册表用户名
    -t, --token TOKEN       镜像注册表访问令牌
    -w, --workdir PATH      工作目录 (默认: 自动创建)
    -h, --help              显示帮助信息

示例:
    # 基本部署
    ./remote-deploy.sh
    
    # 指定镜像版本
    ./remote-deploy.sh \
        -B ghcr.io/your-org/v7/backend:v1.0.0 \
        -W ghcr.io/your-org/v7/web:v1.0.0
    
    # 使用私有注册表
    ./remote-deploy.sh \
        -u your-username \
        -t your-token
        
    # 指定仓库和分支
    ./remote-deploy.sh \
        -r https://github.com/your-org/v7.git \
        -b develop

注意:
    - 确保已安装podman和podman-compose
    - 确保有足够的磁盘空间（建议至少2GB）
    - 确保端口3000和8080未被占用
EOF
}

# 🎯 主函数
main() {
    local repo_url="https://github.com/your-org/v7.git"
    local branch="main"
    local backend_image="ghcr.io/your-org/v7/backend:latest"
    local web_image="ghcr.io/your-org/v7/web:latest"
    local username=""
    local token=""
    local work_dir=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--repo)
                repo_url="$2"
                shift 2
                ;;
            -b|--branch)
                branch="$2"
                shift 2
                ;;
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
            -w|--workdir)
                work_dir="$2"
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
    
    # 显示部署信息
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
    
    if [[ -z "$work_dir" ]]; then
        work_dir=$(download_deployment_config "$repo_url" "$branch")
    fi
    
    setup_environment "$work_dir" "$backend_image" "$web_image"
    login_registry "ghcr.io" "$username" "$token"
    pull_images "$backend_image" "$web_image"
    stop_existing_services "$work_dir"
    start_services "$work_dir"
    
    if health_check "$work_dir"; then
        deployment_summary "$work_dir" "$backend_image" "$web_image"
    else
        log_error "部署失败，请检查日志"
        exit 1
    fi
}

# 运行主函数
main "$@" 