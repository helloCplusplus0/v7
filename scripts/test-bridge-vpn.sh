#!/bin/bash

# 🧪 Bridge网络容器访问VPN验证脚本
# 用于验证Bridge网络模式下容器是否能访问WireGuard VPN网段

set -euo pipefail

# 🎨 输出颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 📋 显示测试说明
show_test_info() {
    cat << 'EOF'
🧪 Bridge网络容器VPN访问验证
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 测试目标：
   验证Bridge网络模式下的容器是否能访问WireGuard VPN网段

🔍 测试内容：
   1. 主机VPN状态检查
   2. 创建临时Bridge网络
   3. 启动测试容器并验证VPN访问
   4. 测试具体的Analytics Engine连接

📝 预期结果：
   Bridge网络容器应该能够通过主机的wg0接口访问10.0.0.x网段
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

# 🔍 检查VPN状态
check_vpn_status() {
    log_info "检查主机WireGuard VPN状态..."
    
    if ! command -v wg &> /dev/null; then
        log_error "WireGuard未安装"
        return 1
    fi
    
    if ! ip link show wg0 &> /dev/null; then
        log_error "WireGuard接口wg0不存在"
        log_info "请先建立VPN连接: sudo wg-quick up wg0"
        return 1
    fi
    
    if ! wg show wg0 | grep -q "endpoint"; then
        log_warning "WireGuard接口存在但未连接"
        return 1
    fi
    
    # 显示VPN详情
    local wg_info=$(wg show wg0)
    log_success "WireGuard VPN状态正常"
    echo "VPN详情:"
    echo "$wg_info" | sed 's/^/  /'
    
    # 检查路由
    if ip route show | grep -q "10.0.0.0/24 dev wg0"; then
        log_success "VPN路由配置正确"
    else
        log_warning "未找到预期的VPN路由"
    fi
    
    return 0
}

# 🌐 创建测试网络
create_test_network() {
    log_info "创建测试Bridge网络..."
    
    # 清理可能存在的测试网络
    podman network rm test-bridge-vpn &>/dev/null || true
    
    # 创建Bridge网络
    podman network create test-bridge-vpn \
        --driver bridge \
        --subnet 172.30.0.0/16 \
        --gateway 172.30.0.1
    
    log_success "测试网络创建成功"
    
    # 显示网络信息
    podman network inspect test-bridge-vpn | jq '.[] | {Name: .name, Driver: .driver, Subnet: .subnets[0].subnet}' || true
}

# 🧪 测试容器VPN访问
test_container_vpn_access() {
    log_info "测试容器VPN网段访问能力..."
    
    # 基础网络连通性测试
    log_info "测试1: ping VPN网关..."
    if podman run --rm --network=test-bridge-vpn alpine:latest \
        timeout 10 ping -c 3 10.0.0.1; then
        log_success "容器可以ping通VPN网关 (10.0.0.1)"
    else
        log_error "容器无法ping通VPN网关"
        return 1
    fi
    
    # 路由检查
    log_info "测试2: 检查容器内路由..."
    podman run --rm --network=test-bridge-vpn alpine:latest \
        sh -c "
        echo '容器内路由表:';
        ip route show;
        echo;
        echo '网络接口:';
        ip addr show;
        " | sed 's/^/  /'
    
    # HTTP连接测试（如果Analytics Engine可用）
    log_info "测试3: HTTP连接测试..."
    if podman run --rm --network=test-bridge-vpn alpine:latest \
        timeout 15 wget -qO- http://10.0.0.1:50051/health 2>/dev/null; then
        log_success "容器可以HTTP访问Analytics Engine"
    else
        log_warning "容器无法HTTP访问Analytics Engine (可能未运行)"
    fi
}

# 🔧 测试实际应用场景
test_application_scenario() {
    log_info "测试应用场景: 模拟Backend容器..."
    
    # 模拟Backend容器的网络访问模式
    log_info "启动模拟Backend容器..."
    podman run --rm -d \
        --name test-backend \
        --network=test-bridge-vpn \
        -p 13000:3000 \
        alpine:latest \
        sh -c "
        # 安装工具
        apk add --no-cache curl wget;
        
        # 保持运行
        while true; do
            echo 'Backend容器运行中...';
            sleep 30;
        done
        "
    
    # 等待容器启动
    sleep 3
    
    # 测试容器内的VPN访问
    log_info "从模拟Backend容器内测试VPN访问..."
    
    if podman exec test-backend \
        wget -q --spider --timeout=10 http://10.0.0.1:50051/health; then
        log_success "模拟Backend容器可以访问Analytics Engine"
    else
        log_warning "模拟Backend容器无法访问Analytics Engine"
    fi
    
    # 测试容器间通信（模拟Web → Backend）
    log_info "测试容器间通信..."
    if podman run --rm --network=test-bridge-vpn alpine:latest \
        timeout 10 wget -qO- http://test-backend:3000 2>/dev/null; then
        log_success "容器间可以通过hostname通信"
    else
        log_info "容器间通信测试（预期可能失败，因为test-backend没有实际HTTP服务）"
    fi
    
    # 清理测试容器
    podman stop test-backend &>/dev/null || true
    podman rm test-backend &>/dev/null || true
}

# 🧹 清理测试资源
cleanup() {
    log_info "清理测试资源..."
    
    # 停止测试容器
    podman stop test-backend &>/dev/null || true
    podman rm test-backend &>/dev/null || true
    
    # 删除测试网络
    podman network rm test-bridge-vpn &>/dev/null || true
    
    log_success "清理完成"
}

# 📊 显示测试结果总结
show_test_summary() {
    echo
    echo "📊 测试结果总结"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ 核心结论: Bridge网络容器可以访问主机WireGuard VPN网段"
    echo
    echo "🔧 技术原理:"
    echo "  1. WireGuard在主机创建wg0虚拟网络接口"
    echo "  2. Bridge网络容器通过主机网络堆栈进行路由"
    echo "  3. 10.0.0.x网段流量自动通过wg0接口转发"
    echo "  4. 容器无需特殊配置即可访问VPN网段"
    echo
    echo "🎯 应用意义:"
    echo "  - Backend容器(bridge网络) + WireGuard VPN 完全可行"
    echo "  - 无需使用host网络模式"
    echo "  - Web和Backend可在同一bridge网络正常通信"
    echo "  - Backend通过VPN访问本地Analytics Engine"
    echo
}

# 📋 主函数
main() {
    # 设置错误时清理
    trap cleanup EXIT
    
    show_test_info
    echo
    
    # 执行测试步骤
    check_vpn_status || { log_error "VPN状态检查失败，退出测试"; exit 1; }
    echo
    
    create_test_network
    echo
    
    test_container_vpn_access || { log_error "VPN访问测试失败"; exit 1; }
    echo
    
    test_application_scenario
    echo
    
    show_test_summary
    
    log_success "🧪 Bridge网络VPN访问验证完成！"
}

# 🚀 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 