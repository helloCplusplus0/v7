#!/bin/bash

# FMOD v7 Podman 部署脚本
set -e

# 配置变量
REGISTRY="192.168.31.84:5000"
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

# 检查 Podman 是否安装
check_podman() {
    if ! command -v podman &> /dev/null; then
        log_error "Podman 未安装，请先安装 Podman"
        exit 1
    fi
    log_info "Podman 版本: $(podman --version)"
}

# 检查 Podman Compose 是否安装
check_podman_compose() {
    if ! command -v podman-compose &> /dev/null; then
        log_warning "Podman Compose 未安装，尝试安装..."
        pip3 install podman-compose
    fi
    log_info "Podman Compose 版本: $(podman-compose --version)"
}

# 构建镜像
build_images() {
    log_info "开始构建镜像..."
    
    # 构建后端镜像
    log_info "构建后端镜像..."
    podman build -t $BACKEND_IMAGE:$VERSION -f backend/Dockerfile backend/
    podman tag $BACKEND_IMAGE:$VERSION $BACKEND_IMAGE:latest
    
    # 构建前端镜像
    log_info "构建前端镜像..."
    podman build -t $FRONTEND_IMAGE:$VERSION -f web/Dockerfile web/
    podman tag $FRONTEND_IMAGE:$VERSION $FRONTEND_IMAGE:latest
    
    log_success "镜像构建完成"
}

# 停止现有服务
stop_services() {
    log_info "停止现有服务..."
    podman-compose down --remove-orphans || true
    log_success "服务已停止"
}

# 启动服务
start_services() {
    log_info "启动服务..."
    podman-compose up -d
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    check_services
}

# 检查服务状态
check_services() {
    log_info "检查服务状态..."
    
    # 检查后端
    if curl -f http://localhost:3000/health &>/dev/null; then
        log_success "后端服务正常运行"
    else
        log_error "后端服务启动失败"
        podman logs fmod-backend --tail 20
        exit 1
    fi
    
    # 检查前端
    if curl -f http://localhost/health &>/dev/null; then
        log_success "前端服务正常运行"
    else
        log_error "前端服务启动失败"
        podman logs fmod-frontend --tail 20
        exit 1
    fi
}

# 备份数据库
backup_database() {
    log_info "备份数据库..."
    mkdir -p ./backups
    
    if podman volume exists ${PROJECT_NAME}_backend_data; then
        BACKUP_FILE="./backups/fmod_backup_$(date +%Y%m%d_%H%M%S).db"
        podman run --rm \
            -v ${PROJECT_NAME}_backend_data:/data:ro \
            -v $(pwd)/backups:/backups \
            alpine:latest \
            sh -c "apk add --no-cache sqlite && sqlite3 /data/prod.db '.backup /backups/$(basename $BACKUP_FILE)'"
        log_success "数据库备份完成: $BACKUP_FILE"
    else
        log_warning "数据卷不存在，跳过备份"
    fi
}

# 查看日志
show_logs() {
    echo "=== 后端日志 ==="
    podman logs fmod-backend --tail 50
    echo ""
    echo "=== 前端日志 ==="
    podman logs fmod-frontend --tail 50
}

# 清理资源
cleanup() {
    log_info "清理未使用的资源..."
    podman system prune -f
    log_success "清理完成"
}

# 主函数
main() {
    case "${1:-deploy}" in
        "build")
            check_podman
            build_images
            ;;
        "deploy")
            check_podman
            check_podman_compose
            backup_database
            build_images
            stop_services
            start_services
            log_success "部署完成！"
            log_info "前端访问地址: http://localhost"
            log_info "后端 API 地址: http://localhost:3000"
            ;;
        "start")
            check_podman_compose
            start_services
            ;;
        "stop")
            check_podman_compose
            stop_services
            ;;
        "restart")
            check_podman_compose
            stop_services
            start_services
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
            check_services
            ;;
        *)
            echo "使用方法: $0 {build|deploy|start|stop|restart|logs|backup|cleanup|status}"
            echo ""
            echo "命令说明:"
            echo "  build   - 仅构建镜像"
            echo "  deploy  - 完整部署（构建 + 部署）"
            echo "  start   - 启动服务"
            echo "  stop    - 停止服务"
            echo "  restart - 重启服务"
            echo "  logs    - 查看日志"
            echo "  backup  - 备份数据库"
            echo "  cleanup - 清理未使用资源"
            echo "  status  - 检查服务状态"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@" 