#!/bin/bash

# FMOD v7 智能端口管理 Podman 部署脚本
set -e

# 配置变量
PROJECT_NAME="fmod-v7"
BACKEND_IMAGE="fmod-backend"
FRONTEND_IMAGE="fmod-frontend"
VERSION=${1:-latest}

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 智能端口检测函数
find_available_port() {
    local start_port=$1
    local max_attempts=${2:-50}
    local max_port=$((start_port + max_attempts))
    
    for port in $(seq $start_port $max_port); do
        # 检查端口是否被占用
        if ! ss -tulpn 2>/dev/null | grep -q ":$port " && \
           ! netstat -tulpn 2>/dev/null | grep -q ":$port "; then
            echo $port
            return 0
        fi
    done
    
    # 如果找不到可用端口，返回原始端口
    log_warning "在 $start_port-$max_port 范围内未找到可用端口，返回原始端口 $start_port"
    echo $start_port
}

# 检查端口是否被占用
is_port_in_use() {
    local port=$1
    ss -tulpn 2>/dev/null | grep -q ":$port " || netstat -tulpn 2>/dev/null | grep -q ":$port "
}

# 获取端口配置
get_port_config() {
    local env=${ENVIRONMENT:-production}
    
    if [ "$env" = "staging" ]; then
        # 测试环境端口配置
        PREFERRED_FRONTEND_PORT=${FRONTEND_PORT_STAGING:-5173}
        PREFERRED_BACKEND_PORT=${BACKEND_PORT_STAGING:-3001}
    else
        # 生产环境端口配置（默认使用8080而非80避免权限问题）
        PREFERRED_FRONTEND_PORT=${FRONTEND_PORT_PRODUCTION:-8080}
        PREFERRED_BACKEND_PORT=${BACKEND_PORT_PRODUCTION:-3000}
    fi
    
    # 智能分配端口
    FRONTEND_PORT=$(find_available_port $PREFERRED_FRONTEND_PORT)
    BACKEND_PORT=$(find_available_port $PREFERRED_BACKEND_PORT)
    
    # 输出端口分配信息
    log_info "端口配置："
    log_info "  环境: $env"
    log_info "  前端端口: $FRONTEND_PORT (首选: $PREFERRED_FRONTEND_PORT)"
    log_info "  后端端口: $BACKEND_PORT (首选: $PREFERRED_BACKEND_PORT)"
    
    # 警告端口变更
    if [ "$FRONTEND_PORT" != "$PREFERRED_FRONTEND_PORT" ]; then
        log_warning "前端端口 $PREFERRED_FRONTEND_PORT 被占用，自动分配到 $FRONTEND_PORT"
    fi
    
    if [ "$BACKEND_PORT" != "$PREFERRED_BACKEND_PORT" ]; then
        log_warning "后端端口 $PREFERRED_BACKEND_PORT 被占用，自动分配到 $BACKEND_PORT"
    fi
    
    # 保存端口信息到文件
    echo "FRONTEND_PORT=$FRONTEND_PORT" > .port-config
    echo "BACKEND_PORT=$BACKEND_PORT" >> .port-config
    echo "ENVIRONMENT=$env" >> .port-config
    echo "TIMESTAMP=$(date)" >> .port-config
}

# 检查 Podman 是否安装
check_podman() {
    if ! command -v podman &> /dev/null; then
        log_error "Podman 未安装，请先安装 Podman"
        echo "Ubuntu/Debian: sudo apt install -y podman"
        echo "CentOS/RHEL: sudo dnf install -y podman"
        exit 1
    fi
    log_info "Podman 版本: $(podman --version)"
}

# 构建镜像
build_images() {
    log_info "构建应用镜像..."
    
    # 构建后端镜像
    log_info "构建后端镜像..."
    if ! podman build -t $BACKEND_IMAGE:$VERSION -f backend/Dockerfile backend/; then
        log_error "后端镜像构建失败"
        exit 1
    fi
    
    # 构建前端镜像
    log_info "构建前端镜像..."
    if ! podman build -t $FRONTEND_IMAGE:$VERSION -f web/Dockerfile web/; then
        log_error "前端镜像构建失败"
        exit 1
    fi
    
    log_success "镜像构建完成"
}

# 停止服务
stop_services() {
    log_info "安全停止现有服务..."
    local env=${ENVIRONMENT:-production}
    
    # 优雅停止后端容器
    if podman ps -q --filter name=fmod-backend-$env | grep -q .; then
        log_info "停止现有后端容器..."
        podman stop fmod-backend-$env --timeout 30 || true
        podman rm fmod-backend-$env || true
        log_success "后端容器已停止"
    fi
    
    # 优雅停止前端容器
    if podman ps -q --filter name=fmod-frontend-$env | grep -q .; then
        log_info "停止现有前端容器..."
        podman stop fmod-frontend-$env --timeout 30 || true
        podman rm fmod-frontend-$env || true
        log_success "前端容器已停止"
    fi
}

# 启动服务
start_services() {
    log_info "启动服务..."
    local env=${ENVIRONMENT:-production}
    
    log_info "启动环境: $env"
    log_info "前端端口: $FRONTEND_PORT, 后端端口: $BACKEND_PORT"
    
    # 创建数据卷（如果不存在）
    podman volume create fmod-data-$env 2>/dev/null || true
    
    # 启动后端容器
    log_info "启动后端容器..."
    podman run -d \
        --name fmod-backend-$env \
        -p $BACKEND_PORT:3000 \
        -v fmod-data-$env:/app/data \
        -e RUST_LOG=info \
        -e DATABASE_URL=sqlite:./data/prod.db \
        -e ENABLE_PERSISTENCE=true \
        -e CREATE_TEST_DATA=false \
        --restart unless-stopped \
        $BACKEND_IMAGE:$VERSION
    
    # 启动前端容器
    log_info "启动前端容器..."
    podman run -d \
        --name fmod-frontend-$env \
        -p $FRONTEND_PORT:80 \
        --restart unless-stopped \
        $FRONTEND_IMAGE:$VERSION
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    check_services $env
}

# 检查服务状态
check_services() {
    local env=${1:-production}
    
    log_info "检查服务状态..."
    
    # 检查容器状态
    if podman ps --filter name=fmod-backend-$env --format "{{.Status}}" | grep -q "Up"; then
        log_success "后端容器运行正常"
    else
        log_error "后端容器运行异常"
        podman logs fmod-backend-$env --tail 20
        return 1
    fi
    
    if podman ps --filter name=fmod-frontend-$env --format "{{.Status}}" | grep -q "Up"; then
        log_success "前端容器运行正常"
    else
        log_error "前端容器运行异常"
        podman logs fmod-frontend-$env --tail 20
        return 1
    fi
    
    # 智能健康检查
    log_info "进行健康检查..."
    
    # 后端健康检查（多次重试）
    local backend_health="❌"
    for i in {1..6}; do
        if curl -sf "http://localhost:$BACKEND_PORT/health" >/dev/null 2>&1; then
            backend_health="✅"
            break
        fi
        log_info "后端健康检查 $i/6 失败，等待5秒后重试..."
        sleep 5
    done
    
    # 前端健康检查（多次重试）
    local frontend_health="❌"
    for i in {1..6}; do
        if curl -sf "http://localhost:$FRONTEND_PORT/" >/dev/null 2>&1; then
            frontend_health="✅"
            break
        fi
        log_info "前端健康检查 $i/6 失败，等待5秒后重试..."
        sleep 5
    done
    
    # 输出详细的部署报告
    echo ""
    echo "🎯 部署完成报告："
    echo "┌─────────────────────────────────────────┐"
    echo "│              FMOD v7 部署状态           │"
    echo "├─────────────────────────────────────────┤"
    echo "│ 环境: $env                             │"
    echo "│ 前端: $frontend_health http://localhost:$FRONTEND_PORT              │"
    echo "│ 后端: $backend_health http://localhost:$BACKEND_PORT                │"
    echo "│ API:  http://localhost:$BACKEND_PORT/health      │"
    echo "└─────────────────────────────────────────┘"
    
    if [ "$backend_health" = "❌" ] || [ "$frontend_health" = "❌" ]; then
        log_error "健康检查失败，部署可能存在问题"
        return 1
    fi
    
    log_success "所有服务健康检查通过"
}

# 显示端口信息
show_port_info() {
    local env=${ENVIRONMENT:-production}
    
    if [ -f .port-config ]; then
        echo "📊 当前端口配置："
        cat .port-config
    fi
    
    echo ""
    echo "🌐 服务访问地址："
    echo "  前端应用: http://localhost:${FRONTEND_PORT:-未知}"
    echo "  后端API:  http://localhost:${BACKEND_PORT:-未知}"
    echo "  健康检查: http://localhost:${BACKEND_PORT:-未知}/health"
}

# 显示日志
show_logs() {
    local env=${ENVIRONMENT:-production}
    
    echo "=== 后端日志 ==="
    podman logs --tail 50 fmod-backend-$env 2>/dev/null || echo "后端容器未运行"
    
    echo ""
    echo "=== 前端日志 ==="
    podman logs --tail 50 fmod-frontend-$env 2>/dev/null || echo "前端容器未运行"
}

# 备份数据库
backup_database() {
    log_info "备份数据库..."
    
    local env=${ENVIRONMENT:-production}
    local backup_dir="backups"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    # 创建备份目录
    mkdir -p $backup_dir
    
    # 备份数据库
    if podman volume exists fmod-data-$env; then
        podman run --rm \
            -v fmod-data-$env:/data:ro \
            -v $(pwd)/$backup_dir:/backup \
            alpine:latest \
            sh -c "if [ -f /data/prod.db ]; then cp /data/prod.db /backup/fmod-$env-$timestamp.db; echo 'Backup completed'; else echo 'No database found'; fi"
        
        log_success "数据库备份完成: $backup_dir/fmod-$env-$timestamp.db"
    else
        log_warning "数据卷不存在，跳过备份"
    fi
}

# 清理资源
cleanup() {
    log_info "清理未使用的资源..."
    
    # 清理悬空镜像
    podman image prune -f >/dev/null 2>&1 || true
    
    # 清理停止的容器
    podman container prune -f >/dev/null 2>&1 || true
    
    log_success "资源清理完成"
}

# 显示状态
show_status() {
    echo "🐳 FMOD v7 容器状态："
    echo ""
    
    # 显示容器状态
    podman ps -a --filter name=fmod --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    echo "💾 数据卷状态："
    podman volume ls --filter name=fmod --format "table {{.Name}}\t{{.Driver}}"
    
    echo ""
    echo "📊 镜像状态："
    podman images --filter reference=fmod* --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.Created}}"
    
    echo ""
    show_port_info
}

# 主函数
main() {
    case "${1:-help}" in
        "build")
            log_info "构建 FMOD v7 镜像..."
            check_podman
            build_images
            ;;
        "deploy")
            log_info "完整部署 FMOD v7..."
            check_podman
            get_port_config
            backup_database
            build_images
            stop_services
            start_services
            cleanup
            show_port_info
            ;;
        "start")
            log_info "启动 FMOD v7 服务..."
            check_podman
            get_port_config
            start_services
            show_port_info
            ;;
        "stop")
            log_info "停止 FMOD v7 服务..."
            stop_services
            ;;
        "restart")
            log_info "重启 FMOD v7 服务..."
            check_podman
            get_port_config
            stop_services
            start_services
            show_port_info
            ;;
        "logs")
            show_logs
            ;;
        "backup")
            backup_database
            ;;
        "cleanup")
            cleanup
            ;;
        "status")
            show_status
            ;;
        "ports")
            show_port_info
            ;;
        "help"|"-h"|"--help")
            echo "FMOD v7 智能端口管理部署脚本"
            echo ""
            echo "使用方法: $0 {命令} [选项]"
            echo ""
            echo "可用命令:"
            echo "  build     - 仅构建镜像"
            echo "  deploy    - 完整部署（备份 + 构建 + 部署 + 清理）"
            echo "  start     - 启动服务"
            echo "  stop      - 停止服务"
            echo "  restart   - 重启服务"
            echo "  logs      - 查看服务日志"
            echo "  backup    - 备份数据库"
            echo "  cleanup   - 清理未使用资源"
            echo "  status    - 显示服务状态"
            echo "  ports     - 显示端口配置信息"
            echo "  help      - 显示此帮助信息"
            echo ""
            echo "环境变量:"
            echo "  ENVIRONMENT               - 部署环境 (production|staging，默认: production)"
            echo "  FRONTEND_PORT_PRODUCTION  - 生产环境前端端口 (默认: 8080)"
            echo "  BACKEND_PORT_PRODUCTION   - 生产环境后端端口 (默认: 3000)"
            echo "  FRONTEND_PORT_STAGING     - 测试环境前端端口 (默认: 5173)"
            echo "  BACKEND_PORT_STAGING      - 测试环境后端端口 (默认: 3001)"
            echo ""
            echo "端口智能管理："
            echo "  - 自动检测端口占用情况"
            echo "  - 如果首选端口被占用，自动分配下一个可用端口"
            echo "  - 配置信息保存在 .port-config 文件中"
            echo ""
            echo "示例:"
            echo "  $0 deploy                              # 部署到生产环境（端口自动分配）"
            echo "  ENVIRONMENT=staging $0 start           # 启动测试环境"
            echo "  FRONTEND_PORT_PRODUCTION=9090 $0 deploy # 生产环境使用自定义前端端口"
            echo "  $0 ports                               # 查看当前端口配置"
            echo "  $0 status                              # 查看详细状态"
            ;;
        *)
            log_error "未知命令: $1"
            echo "使用 '$0 help' 查看可用命令"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@" 