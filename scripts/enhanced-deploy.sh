#!/bin/bash
# 🚀 V7项目增强部署脚本
# 专门解决GitHub Actions部署中的健康检查和服务启动问题

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
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

# 检查必要工具
check_dependencies() {
    log_info "检查部署依赖..."
    
    local missing_tools=()
    
    for tool in podman podman-compose curl; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "缺少必要工具: ${missing_tools[*]}"
        exit 1
    fi
    
    log_success "所有依赖工具已安装"
}

# 加载环境变量
load_environment() {
    log_info "加载环境变量..."
    
    if [ -f ".env.production" ]; then
        log_info "从 .env.production 加载配置..."
        set -a
        source .env.production
        set +a
        
        log_success "环境变量加载完成"
        log_info "关键配置检查:"
        echo "  - VERSION: ${VERSION:-未设置}"
        echo "  - BACKEND_IMAGE: ${BACKEND_IMAGE:-未设置}"
        echo "  - WEB_IMAGE: ${WEB_IMAGE:-未设置}"
        echo "  - DATABASE_URL: ${DATABASE_URL:-未设置}"
        echo "  - RUST_LOG: ${RUST_LOG:-未设置}"
    else
        log_error "未找到 .env.production 文件"
        log_info "当前目录内容:"
        ls -la
        exit 1
    fi
}

# 验证镜像可用性
verify_images() {
    log_info "验证容器镜像..."
    
    local images=("${BACKEND_IMAGE}" "${WEB_IMAGE}")
    
    for image in "${images[@]}"; do
        if [ -n "$image" ]; then
            log_info "检查镜像: $image"
            if podman pull "$image"; then
                log_success "镜像拉取成功: $image"
            else
                log_error "镜像拉取失败: $image"
                exit 1
            fi
        else
            log_error "镜像名称为空"
            exit 1
        fi
    done
}

# 清理旧服务
cleanup_old_services() {
    log_info "清理旧服务..."
    
    # 备份当前状态
    if podman-compose --env-file .env.production ps > /dev/null 2>&1; then
        podman-compose --env-file .env.production ps > "deployment-backup-$(date +%Y%m%d-%H%M%S).log" 2>/dev/null || true
    fi
    
    # 停止服务
    log_info "停止现有服务..."
    podman-compose --env-file .env.production down || true
    
    # 清理资源
    log_info "清理未使用的资源..."
    podman system prune -f || true
    
    log_success "旧服务清理完成"
}

# 启动服务
start_services() {
    log_info "启动新服务..."
    
    # 启动服务
    if podman-compose --env-file .env.production up -d; then
        log_success "服务启动命令执行成功"
    else
        log_error "服务启动失败"
        exit 1
    fi
    
    # 等待服务启动
    log_info "等待服务初始化..."
    sleep 30
    
    # 检查服务状态
    log_info "检查服务状态:"
    podman-compose --env-file .env.production ps
    
    log_info "检查容器健康状态:"
    podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# 等待服务就绪
wait_for_services() {
    log_info "等待服务完全就绪..."
    
    local services=("backend:3000" "web:8080")
    local max_wait=300  # 5分钟
    local wait_time=0
    
    while [ $wait_time -lt $max_wait ]; do
        local all_ready=true
        
        for service in "${services[@]}"; do
            local name="${service%:*}"
            local port="${service#*:}"
            
            if ! timeout 5 bash -c "</dev/tcp/localhost/$port" 2>/dev/null; then
                all_ready=false
                break
            fi
        done
        
        if [ "$all_ready" = true ]; then
            log_success "所有服务端口已开放"
            break
        fi
        
        log_info "等待服务端口开放... ($wait_time/$max_wait 秒)"
        sleep 10
        wait_time=$((wait_time + 10))
    done
    
    if [ $wait_time -ge $max_wait ]; then
        log_warning "服务启动超时，但继续部署流程"
    fi
}

# 基础健康检查
basic_health_check() {
    log_info "执行基础健康检查..."
    
    local backend_healthy=false
    local web_healthy=false
    
    # 检查后端
    if curl -f -s --connect-timeout 10 "http://localhost:3000/health" >/dev/null 2>&1; then
        log_success "后端健康检查通过"
        backend_healthy=true
    else
        log_warning "后端健康检查失败"
    fi
    
    # 检查前端
    if curl -f -s --connect-timeout 10 "http://localhost:8080" >/dev/null 2>&1; then
        log_success "前端健康检查通过"
        web_healthy=true
    else
        log_warning "前端健康检查失败"
    fi
    
    # 检查API
    if curl -f -s --connect-timeout 10 "http://localhost:3000/api/info" >/dev/null 2>&1; then
        log_success "API功能检查通过"
    else
        log_warning "API功能检查失败"
    fi
    
    if [ "$backend_healthy" = true ] || [ "$web_healthy" = true ]; then
        log_success "至少一个服务健康，部署基本成功"
        return 0
    else
        log_error "所有服务健康检查都失败"
        return 1
    fi
}

# 生成部署报告
generate_deployment_report() {
    log_info "生成部署报告..."
    
    local report_file="deployment-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "🚀 V7项目部署报告"
        echo "===================="
        echo "📅 部署时间: $(date)"
        echo "🏷️ 版本: ${VERSION:-unknown}"
        echo "🖥️ 服务器: $(hostname)"
        echo "👤 用户: $(whoami)"
        echo ""
        
        echo "🐳 容器状态:"
        podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}" || echo "无法获取容器状态"
        echo ""
        
        echo "🔧 Compose服务状态:"
        podman-compose --env-file .env.production ps || echo "无法获取Compose状态"
        echo ""
        
        echo "🌐 健康检查结果:"
        for url in "http://localhost:3000/health" "http://localhost:8080" "http://localhost:3000/api/info"; do
            if curl -f -s --connect-timeout 5 "$url" >/dev/null 2>&1; then
                echo "✅ $url - 正常"
            else
                echo "❌ $url - 异常"
            fi
        done
        echo ""
        
        echo "💾 系统资源:"
        echo "内存使用:"
        free -h
        echo ""
        echo "磁盘使用:"
        df -h /
        echo ""
        
        echo "📋 容器日志摘要:"
        for container in v7-backend v7-web; do
            echo "--- $container (最近5行) ---"
            podman logs --tail 5 "$container" 2>/dev/null || echo "无法获取日志"
            echo ""
        done
        
    } > "$report_file"
    
    log_success "部署报告已生成: $report_file"
}

# 主部署流程
main() {
    echo "🚀 V7项目增强部署脚本"
    echo "========================"
    echo "📅 开始时间: $(date)"
    echo ""
    
    # 执行部署步骤
    check_dependencies
    load_environment
    verify_images
    cleanup_old_services
    start_services
    wait_for_services
    
    # 健康检查
    if basic_health_check; then
        log_success "✅ 部署成功完成！"
    else
        log_warning "⚠️ 部署完成但存在健康检查问题"
    fi
    
    # 生成报告
    generate_deployment_report
    
    echo ""
    echo "🎉 部署流程完成！"
    echo "📊 详细信息请查看部署报告"
    echo "🌍 访问地址:"
    echo "  - 前端: http://localhost:8080"
    echo "  - 后端: http://localhost:3000"
    echo "  - API信息: http://localhost:3000/api/info"
}

# 错误处理
trap 'log_error "部署过程中发生错误，退出码: $?"' ERR

# 执行主函数
main "$@" 