#!/bin/bash

# 🔐 WireGuard客户端配置脚本（云服务器端）
# 用于建立与本地analytics-engine的VPN连接

set -euo pipefail

# 🎨 输出颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

show_usage() {
    cat << EOF
🔐 WireGuard客户端配置脚本

用法: $0 <server_public_key> [server_endpoint]

参数:
  server_public_key  - 本地服务器的公钥 (必需)
  server_endpoint    - 本地服务器的公网地址:端口 (可选，默认会提示输入)

示例:
  $0 "ZS3sA6xk9t8zTyNTodV2SSSqTq/Y38THx5ah9iq0I1c=" "192.168.31.84:51820"
  $0 "ZS3sA6xk9t8zTyNTodV2SSSqTq/Y38THx5ah9iq0I1c="

注意:
  - 需要从本地服务器获取公钥: sudo cat /etc/wireguard/server-public.key
  - 如果本地没有公网IP，需要配置路由器端口转发
EOF
}

# 检查参数
if [ $# -lt 1 ]; then
    show_usage
    exit 1
fi

SERVER_PUBLIC_KEY="$1"
SERVER_ENDPOINT="${2:-}"

# 检查WireGuard是否安装
if ! command -v wg &> /dev/null; then
    log_error "WireGuard未安装，请先安装："
    echo "sudo apt update && sudo apt install -y wireguard-tools"
    exit 1
fi

log_info "🔐 开始配置WireGuard客户端..."

# 清理现有配置
if [ -f /etc/wireguard/wg0.conf ]; then
    log_warning "发现现有配置，创建备份..."
    sudo cp /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.backup.$(date +%Y%m%d_%H%M%S)
fi

# 停止现有服务
if systemctl is-active --quiet wg-quick@wg0; then
    log_info "停止现有WireGuard服务..."
    sudo systemctl stop wg-quick@wg0 || true
fi

# 生成客户端密钥对
log_info "生成客户端密钥对..."
cd /etc/wireguard
sudo wg genkey | sudo tee client-private.key | wg pubkey | sudo tee client-public.key > /dev/null
sudo chmod 600 client-private.key
sudo chmod 644 client-public.key

CLIENT_PRIVATE_KEY=$(sudo cat client-private.key)
CLIENT_PUBLIC_KEY=$(sudo cat client-public.key)

# 获取服务器端点（如果未提供）
if [ -z "$SERVER_ENDPOINT" ]; then
    echo
    log_info "请输入本地服务器的访问地址："
    echo "  - 如果有公网IP: 直接输入 IP:51820"
    echo "  - 如果没有公网IP: 输入路由器公网IP:转发端口"
    echo "  - 局域网测试: 输入局域网IP:51820"
    echo
    read -p "请输入服务器地址:端口: " SERVER_ENDPOINT
    
    if [ -z "$SERVER_ENDPOINT" ]; then
        log_error "服务器端点不能为空"
        exit 1
    fi
fi

# 创建客户端配置文件
log_info "创建客户端配置文件..."
sudo tee wg0.conf << EOF > /dev/null
[Interface]
# 云端Backend客户端配置
PrivateKey = $CLIENT_PRIVATE_KEY
Address = 10.0.0.2/24
DNS = 8.8.8.8

# 连接保活设置
PersistentKeepalive = 25

[Peer]
# 本地Analytics Engine服务器 (192.168.31.84)
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_ENDPOINT
AllowedIPs = 10.0.0.0/24

# 路由设置：仅通过VPN访问10.0.0.0/24网段
EOF

log_success "客户端配置文件创建完成"

# 显示配置信息
echo
log_info "📋 配置信息总结："
echo "  🔐 客户端VPN IP: 10.0.0.2"
echo "  🏠 服务器VPN IP: 10.0.0.1"
echo "  🌐 服务器端点: $SERVER_ENDPOINT"
echo "  🔑 客户端公钥: $CLIENT_PUBLIC_KEY"
echo

# 提供下一步指令
log_info "📝 下一步操作："
echo "1. 将以下客户端公钥添加到本地服务器："
echo "   sudo wg set wg0 peer $CLIENT_PUBLIC_KEY allowed-ips 10.0.0.2/32"
echo
echo "2. 启动客户端VPN连接："
echo "   sudo systemctl enable wg-quick@wg0"
echo "   sudo systemctl start wg-quick@wg0"
echo
echo "3. 验证连接："
echo "   ping 10.0.0.1"
echo "   curl http://10.0.0.1:50051/health"
echo

# 询问是否立即启动
read -p "是否立即启动VPN连接？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "启动WireGuard客户端..."
    sudo systemctl enable wg-quick@wg0
    sudo systemctl start wg-quick@wg0
    
    # 等待连接建立
    sleep 3
    
    # 检查连接状态
    if wg show wg0 &>/dev/null; then
        log_success "WireGuard客户端启动成功"
        
        log_info "连接状态："
        sudo wg show wg0
        
        log_warning "⚠️  重要提醒："
        echo "请在本地服务器执行以下命令添加此客户端："
        echo "sudo wg set wg0 peer $CLIENT_PUBLIC_KEY allowed-ips 10.0.0.2/32"
        echo "sudo wg-quick save wg0"
    else
        log_error "WireGuard客户端启动失败"
        exit 1
    fi
else
    log_info "VPN连接未启动，请手动执行上述步骤"
fi

log_success "�� WireGuard客户端配置完成！" 