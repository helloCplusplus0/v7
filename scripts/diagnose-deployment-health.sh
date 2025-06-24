#!/bin/bash
# 🏥 V7项目部署健康诊断脚本
# 专门诊断和修复GitHub Actions部署中的健康检查失败问题

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 诊断函数
diagnose_container_status() {
    log_info "检查容器状态..."
    
    if command -v podman >/dev/null 2>&1; then
        echo "🐳 Podman容器状态:"
        podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}" || true
        echo ""
        
        echo "🔍 所有容器（包括停止的）:"
        podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Created}}" || true
        echo ""
    else
        log_error "Podman未安装或不可用"
    fi
}

diagnose_network_connectivity() {
    log_info "检查网络连接..."
    
    # 检查端口监听
    echo "🔌 端口监听状态:"
    netstat -tlnp | grep -E ':(3000|8080|9100)' || echo "未发现相关端口监听"
    echo ""
    
    # 检查本地连接
    echo "🌐 本地连接测试:"
    for port in 3000 8080; do
        if curl -f -s --connect-timeout 5 "http://localhost:$port/health" >/dev/null 2>&1; then
            log_success "localhost:$port/health - 可访问"
        else
            log_error "localhost:$port/health - 不可访问"
        fi
    done
    echo ""
}

diagnose_container_logs() {
    log_info "检查容器日志..."
    
    local containers=("v7-backend" "v7-web")
    
    for container in "${containers[@]}"; do
        echo "📋 $container 日志 (最近20行):"
        if podman logs --tail 20 "$container" 2>/dev/null; then
            echo ""
        else
            log_warning "$container 容器不存在或无法访问日志"
        fi
    done
}

diagnose_health_endpoints() {
    log_info "详细检查健康端点..."
    
    # 检查后端健康端点
    echo "🦀 后端健康检查:"
    if curl -v -f --connect-timeout 10 "http://localhost:3000/health" 2>&1; then
        log_success "后端健康端点正常"
    else
        log_error "后端健康端点失败"
    fi
    echo ""
    
    # 检查前端健康端点
    echo "🌐 前端健康检查:"
    if curl -v -f --connect-timeout 10 "http://localhost:8080/health" 2>&1; then
        log_success "前端健康端点正常"
    else
        log_error "前端健康端点失败"
    fi
    echo ""
}

diagnose_compose_config() {
    log_info "检查Compose配置..."
    
    if [ -f "podman-compose.yml" ]; then
        echo "📄 Compose文件存在"
        
        if [ -f ".env.production" ]; then
            echo "🔧 生产环境配置:"
            cat .env.production
            echo ""
        else
            log_warning "未找到 .env.production 文件"
        fi
        
        echo "🔍 Compose服务状态:"
        podman-compose ps || true
        echo ""
    else
        log_error "未找到 podman-compose.yml 文件"
    fi
}

# 修复函数
fix_backend_health_endpoint() {
    log_info "修复后端健康端点..."
    
    # 检查后端容器是否运行
    if ! podman ps | grep -q "v7-backend"; then
        log_warning "后端容器未运行，尝试启动..."
        
        if [ -f "podman-compose.yml" ] && [ -f ".env.production" ]; then
            podman-compose --env-file .env.production up -d backend
            sleep 30
        else
            log_error "缺少必要的配置文件"
            return 1
        fi
    fi
    
    # 等待并重试健康检查
    local max_attempts=15
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "健康检查尝试 $attempt/$max_attempts..."
        
        if curl -f -s --connect-timeout 10 "http://localhost:3000/health" >/dev/null; then
            log_success "后端健康检查成功"
            return 0
        fi
        
        sleep 10
        ((attempt++))
    done
    
    log_error "后端健康检查修复失败"
    return 1
}

fix_frontend_health_endpoint() {
    log_info "修复前端健康端点..."
    
    # 检查前端容器是否运行
    if ! podman ps | grep -q "v7-web"; then
        log_warning "前端容器未运行，尝试启动..."
        
        if [ -f "podman-compose.yml" ] && [ -f ".env.production" ]; then
            podman-compose --env-file .env.production up -d web
            sleep 20
        else
            log_error "缺少必要的配置文件"
            return 1
        fi
    fi
    
    # 等待并重试健康检查
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "前端健康检查尝试 $attempt/$max_attempts..."
        
        if curl -f -s --connect-timeout 10 "http://localhost:8080" >/dev/null; then
            log_success "前端健康检查成功"
            return 0
        fi
        
        sleep 10
        ((attempt++))
    done
    
    log_error "前端健康检查修复失败"
    return 1
}

restart_services() {
    log_info "重启所有服务..."
    
    if [ -f "podman-compose.yml" ] && [ -f ".env.production" ]; then
        # 停止服务
        log_info "停止现有服务..."
        podman-compose --env-file .env.production down || true
        
        # 清理
        log_info "清理资源..."
        podman system prune -f || true
        
        # 重新启动
        log_info "重新启动服务..."
        podman-compose --env-file .env.production up -d
        
        # 等待启动
        log_info "等待服务启动..."
        sleep 60
        
        log_success "服务重启完成"
    else
        log_error "缺少必要的配置文件"
        return 1
    fi
}

# 生成健康检查报告
generate_health_report() {
    log_info "生成健康检查报告..."
    
    local report_file="health-check-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "🏥 V7项目健康检查报告"
        echo "=========================="
        echo "📅 生成时间: $(date)"
        echo "🖥️  服务器: $(hostname)"
        echo "👤 用户: $(whoami)"
        echo ""
        
        echo "🐳 容器状态:"
        podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "无法获取容器状态"
        echo ""
        
        echo "🔌 端口监听:"
        netstat -tlnp | grep -E ':(3000|8080|9100)' || echo "未发现相关端口监听"
        echo ""
        
        echo "🌐 健康端点测试:"
        for url in "http://localhost:3000/health" "http://localhost:8080"; do
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
        df -h
        echo ""
        
        echo "📋 最近的容器日志:"
        for container in v7-backend v7-web; do
            echo "--- $container ---"
            podman logs --tail 10 "$container" 2>/dev/null || echo "无法获取日志"
            echo ""
        done
        
    } > "$report_file"
    
    log_success "健康检查报告已生成: $report_file"
}

# 主函数
main() {
    echo "🏥 V7项目部署健康诊断工具"
    echo "============================="
    echo ""
    
    case "${1:-diagnose}" in
        "diagnose")
            log_info "开始全面诊断..."
            diagnose_container_status
            diagnose_network_connectivity
            diagnose_compose_config
            diagnose_container_logs
            diagnose_health_endpoints
            generate_health_report
            ;;
        "fix")
            log_info "开始修复健康检查问题..."
            fix_backend_health_endpoint
            fix_frontend_health_endpoint
            ;;
        "restart")
            log_info "重启所有服务..."
            restart_services
            ;;
        "report")
            generate_health_report
            ;;
        *)
            echo "用法: $0 [diagnose|fix|restart|report]"
            echo ""
            echo "命令说明:"
            echo "  diagnose  - 执行全面诊断 (默认)"
            echo "  fix       - 尝试修复健康检查问题"
            echo "  restart   - 重启所有服务"
            echo "  report    - 生成健康检查报告"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@" 