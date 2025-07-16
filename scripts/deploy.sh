#!/bin/bash
# 🚀 V7项目统一部署脚本
# 
# 功能：构建和部署V7项目的三个服务
# 设计：唯一、清晰、无冗余

set -euo pipefail

# 📋 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 🎨 彩色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_step() { echo -e "${PURPLE}🔄 $1${NC}"; }

# 📝 显示帮助信息
show_help() {
    cat << EOF
🚀 V7项目部署脚本

用法: $0 [选项]

选项:
  --build          只构建镜像，不启动服务
  --deploy         只部署服务，不构建
  --restart        重启现有服务
  --clean          清理并重新构建
  --help           显示此帮助信息

示例:
  $0               # 完整构建和部署流程
  $0 --build       # 只构建镜像
  $0 --clean       # 清理重建
EOF
}

# 🔧 解析命令行参数
BUILD_ONLY=false
DEPLOY_ONLY=false
RESTART_ONLY=false
CLEAN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            BUILD_ONLY=true
            shift
            ;;
        --deploy)
            DEPLOY_ONLY=true
            shift
            ;;
        --restart)
            RESTART_ONLY=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --help)
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

cd "$PROJECT_ROOT"

# 🧹 清理函数
clean_up() {
    if [[ "$CLEAN" == "true" ]]; then
        log_step "清理现有容器和镜像..."
        podman rm -f v7-analytics-engine v7-backend v7-web 2>/dev/null || true
        podman rmi -f v7-analytics-engine:latest v7-backend:latest v7-web:latest 2>/dev/null || true
        log_success "清理完成"
    fi
}

# 🏗️ 构建镜像
build_images() {
    log_step "构建V7项目镜像..."
    
    # 构建Analytics-Engine
    log_info "构建Analytics-Engine..."
    if podman build --network=host --no-cache -t v7-analytics-engine:latest -f analytics-engine/Dockerfile analytics-engine/; then
        log_success "Analytics-Engine构建成功"
    else
        log_error "Analytics-Engine构建失败"
        return 1
    fi
    
    # 构建Backend
    log_info "构建Backend..."
    if podman build --network=host --no-cache -t v7-backend:latest -f backend/Dockerfile backend/; then
        log_success "Backend构建成功"
    else
        log_error "Backend构建失败"
        return 1
    fi
    
    # 构建Web
    log_info "构建Web..."
    if podman build --network=host --no-cache -t v7-web:latest -f web/Dockerfile web/; then
        log_success "Web构建成功"
    else
        log_error "Web构建失败"
        return 1
    fi
    
    log_success "所有镜像构建完成"
}

# 🚀 部署服务
deploy_services() {
    log_step "使用podman-compose部署服务..."
    
    if [[ -f "podman-compose.yml" ]]; then
        podman-compose up -d
        log_success "服务部署完成"
        
        # 显示服务状态
        log_info "服务状态："
        podman-compose ps
    else
        log_error "podman-compose.yml文件不存在"
        return 1
    fi
}

# 🔄 重启服务
restart_services() {
    log_step "重启V7服务..."
    
    if [[ -f "podman-compose.yml" ]]; then
        podman-compose restart
        log_success "服务重启完成"
    else
        log_error "podman-compose.yml文件不存在"
        return 1
    fi
}

# 🎯 主流程
main() {
    log_info "🚀 V7项目部署开始..."
    log_info "工作目录: $PROJECT_ROOT"
    
    # 清理（如果需要）
    clean_up
    
    # 根据参数执行相应操作
    if [[ "$RESTART_ONLY" == "true" ]]; then
        restart_services
    elif [[ "$BUILD_ONLY" == "true" ]]; then
        build_images
    elif [[ "$DEPLOY_ONLY" == "true" ]]; then
        deploy_services
    else
        # 完整流程：构建 + 部署
        build_images && deploy_services
    fi
    
    log_success "🎉 V7项目部署完成！"
    
    # 显示访问信息
    cat << EOF

📱 服务访问地址:
- Web前端:     http://localhost:5173
- Backend API: http://localhost:50053
- Analytics:   http://localhost:50051

🔍 查看日志: podman-compose logs -f [service_name]
🛑 停止服务: podman-compose down
EOF
}

# 🚨 错误处理
trap 'log_error "部署过程中发生错误"; exit 1' ERR

# 执行主流程
main "$@" 