#!/bin/bash

# 🏗️ V7项目集成部署脚本
# 功能：WireGuard VPN + 容器编排一键部署
# 适用：云服务器端自动化部署

set -euo pipefail

# 📋 配置参数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 🎨 输出颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

log_step() {
    echo -e "${PURPLE}🔧 $1${NC}"
}

# 📋 显示横幅
show_banner() {
    cat << 'EOF'
🏗️ V7项目集成部署系统
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 部署内容:
   ├─ 🔐 WireGuard VPN客户端启动
   ├─ 🐳 Backend + Web 容器部署
   ├─ 🔗 VPN连接验证和监控
   └─ 📊 端到端服务验证

📍 架构:
   ☁️ 云端: Backend(bridge) + Web(bridge)
   🔐 VPN: 云端 ←→ 本地局域网
   🏠 本地: Analytics Engine(systemd)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

# 🔍 1. 预检阶段
check_prerequisites() {
    log_step "执行环境预检..."
    
    # 检查必要命令
    local required_commands=("podman" "podman-compose" "wg" "curl" "wget" "ip")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "缺少必要命令: $cmd"
            return 1
        fi
    done
    
    # 检查WireGuard配置
    if [ ! -f /etc/wireguard/wg0.conf ]; then
        log_error "WireGuard配置文件不存在: /etc/wireguard/wg0.conf"
        log_info "请先按照WIREGUARD_DEPLOYMENT_GUIDE.md配置WireGuard客户端"
        return 1
    fi
    
    # 检查容器配置文件
    if [ ! -f "$PROJECT_ROOT/podman-compose-correct.yml" ]; then
        log_error "容器配置文件不存在: podman-compose-correct.yml"
        return 1
    fi
    
    if [ ! -f "$PROJECT_ROOT/compose-correct.env" ]; then
        log_error "环境配置文件不存在: compose-correct.env"
        return 1
    fi
    
    log_success "环境预检通过"
    return 0
}

# 🔐 2. VPN连接管理
manage_vpn_connection() {
    log_step "管理WireGuard VPN连接..."
    
    # 检查当前VPN状态
    if ip link show wg0 &> /dev/null; then
        log_info "WireGuard接口已存在，检查连接状态..."
        if wg show wg0 2>/dev/null | grep -q "endpoint"; then
            log_info "VPN连接正常，继续使用现有连接"
        else
            log_warning "VPN接口存在但未连接，重新启动..."
            sudo wg-quick down wg0 || true
            sudo wg-quick up wg0
        fi
    else
        log_info "启动WireGuard VPN连接..."
        sudo wg-quick up wg0
    fi
    
    # 等待VPN稳定
    log_info "等待VPN连接稳定..."
    sleep 5
    
    # 验证VPN路由
    if ! ip route show | grep -q "10.0.0.0/24 dev wg0"; then
        log_error "VPN路由未正确配置"
        return 1
    fi
    
    log_success "VPN连接建立成功"
    return 0
}

# 🧪 3. Analytics Engine连接测试
test_analytics_connection() {
    log_step "测试Analytics Engine连接..."
    
    local max_attempts=6
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "连接测试 (第 $attempt/$max_attempts 次)..."
        
        if curl -s --connect-timeout 5 --max-time 10 http://10.0.0.1:50051/health > /dev/null; then
            log_success "Analytics Engine连接正常"
            
            # 显示连接详情
            local response=$(curl -s http://10.0.0.1:50051/health || echo "无响应")
            log_info "Analytics Engine响应: $response"
            return 0
        fi
        
        log_warning "连接失败，等待重试..."
        sleep 5
        ((attempt++))
    done
    
    log_error "无法连接到Analytics Engine (http://10.0.0.1:50051)"
    log_info "请检查:"
    log_info "  1. 本地Analytics Engine是否正常运行"
    log_info "  2. WireGuard VPN是否正确配置"
    log_info "  3. 防火墙设置是否正确"
    return 1
}

# 🐳 4. 容器部署
deploy_containers() {
    log_step "部署容器服务..."
    
    cd "$PROJECT_ROOT"
    
    # 准备配置文件
    if [ ! -f podman-compose.yml ] || [ ! -f .env ]; then
        log_info "准备部署配置文件..."
        cp podman-compose-correct.yml podman-compose.yml
        cp compose-correct.env .env
        log_success "配置文件准备完成"
    fi
    
    # 停止现有容器（如果存在）
    log_info "清理现有容器..."
    podman-compose down &>/dev/null || true
    
    # 启动服务
    log_info "启动容器服务..."
    if ! podman-compose up -d; then
        log_error "容器启动失败"
        return 1
    fi
    
    log_success "容器服务启动成功"
    return 0
}

# ⏳ 5. 服务健康检查
wait_for_services() {
    log_step "等待服务启动..."
    
    local max_wait=60
    local waited=0
    
    while [ $waited -lt $max_wait ]; do
        log_info "等待Backend服务就绪... ($waited/${max_wait}s)"
        
        if curl -s --connect-timeout 3 --max-time 5 http://localhost:3000/health > /dev/null; then
            log_success "Backend服务就绪"
            break
        fi
        
        sleep 5
        waited=$((waited + 5))
    done
    
    if [ $waited -ge $max_wait ]; then
        log_error "Backend服务启动超时"
        return 1
    fi
    
    # 检查Web服务
    log_info "检查Web服务..."
    if curl -s --connect-timeout 3 --max-time 5 http://localhost:8080 > /dev/null; then
        log_success "Web服务就绪"
    else
        log_warning "Web服务可能需要更多时间启动"
    fi
    
    return 0
}

# 🧪 6. 端到端验证
run_end_to_end_tests() {
    log_step "执行端到端验证..."
    
    # 测试Backend内部Analytics连接
    log_info "测试Backend → Analytics Engine连接..."
    if podman exec v7-backend wget -q --spider --timeout=10 http://10.0.0.1:50051/health; then
        log_success "Backend可以访问Analytics Engine"
    else
        log_error "Backend无法访问Analytics Engine"
        return 1
    fi
    
    # 测试Web → Backend连接
    log_info "测试Web → Backend连接..."
    if podman exec v7-web wget -q --spider --timeout=10 http://backend:3000/health; then
        log_success "Web可以访问Backend"
    else
        log_error "Web无法访问Backend"
        return 1
    fi
    
    log_success "所有连接测试通过"
    return 0
}

# 📊 7. 部署状态报告
show_deployment_status() {
    log_step "生成部署状态报告..."
    
    echo
    echo "🎉 V7项目部署完成！"
    echo
    echo "📊 服务状态:"
    podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo
    
    echo "🔗 服务访问地址:"
    local server_ip=$(hostname -I | awk '{print $1}')
    echo "  🌐 Web应用:     http://$server_ip:8080"
    echo "  🦀 Backend API: http://$server_ip:3000"
    echo "  📡 gRPC服务:    $server_ip:50053"
    echo
    
    echo "🔐 网络连接状态:"
    if wg show wg0 &>/dev/null; then
        echo "  ✅ WireGuard VPN: 已连接"
        echo "  🏠 Analytics Engine: http://10.0.0.1:50051"
    else
        echo "  ❌ WireGuard VPN: 未连接"
    fi
    echo
    
    echo "🛠️ 管理命令:"
    echo "  查看日志: podman-compose logs -f"
    echo "  重启服务: podman-compose restart"
    echo "  停止服务: podman-compose down"
    echo "  VPN状态:  sudo wg show"
    echo
}

# 🚨 错误处理和清理
cleanup_on_error() {
    log_error "部署过程中出现错误，执行清理..."
    
    # 保存日志
    if command -v podman-compose &> /dev/null; then
        podman-compose logs > /tmp/v7-deploy-error.log 2>&1 || true
        log_info "错误日志已保存到: /tmp/v7-deploy-error.log"
    fi
    
    # 不自动清理VPN连接，因为可能还有其他用途
    log_info "保留VPN连接，如需手动断开请执行: sudo wg-quick down wg0"
}

# 📋 主函数
main() {
    # 错误处理
    trap cleanup_on_error ERR
    
    show_banner
    
    log_info "开始V7项目集成部署..."
    echo
    
    # 执行部署步骤
    check_prerequisites
    echo
    
    manage_vpn_connection
    echo
    
    test_analytics_connection
    echo
    
    deploy_containers
    echo
    
    wait_for_services
    echo
    
    run_end_to_end_tests
    echo
    
    show_deployment_status
    
    log_success "🎉 V7项目集成部署完成！"
}

# 🚀 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 