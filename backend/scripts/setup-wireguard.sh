#!/bin/bash

# 🔐 WireGuard VPN 设置脚本
# 用于连接云端backend和本地analytics-engine (192.168.31.84)
#
# 部署架构：
# ☁️  云端backend     🔐 WireGuard VPN     🏠 本地analytics-engine  
# (公网)              (加密隧道)           (192.168.31.84:50051)
# 10.0.0.2    ←→      51820/udp     ←→    10.0.0.1
#
# 使用方法：
# 1. 在analytics-engine主机(192.168.31.84)上运行: sudo ./setup-wireguard.sh server
# 2. 在云端backend主机上运行: sudo ./setup-wireguard.sh client <server-public-ip>

set -euo pipefail

# 🔧 配置参数
LOCAL_SERVER_IP="192.168.31.84"  # 本地analytics-engine服务器IP
VPN_NETWORK="10.0.0.0/24"        # VPN内网段
SERVER_VPN_IP="10.0.0.1"         # analytics-engine VPN IP
CLIENT_VPN_IP="10.0.0.2"         # backend VPN IP
WG_PORT="51820"                  # WireGuard端口

show_usage() {
    echo "使用方法:"
    echo "  $0 server                    # 在analytics-engine主机上运行"
    echo "  $0 client <server-public-ip> # 在cloud backend主机上运行"
    echo ""
    echo "示例:"
    echo "  sudo $0 server"
    echo "  sudo $0 client 47.100.1.2"
}

if [[ $# -lt 1 ]]; then
    show_usage
    exit 1
fi

MODE="$1"

echo "🔐 开始配置WireGuard VPN - 模式: $MODE"

# 1. 安装WireGuard
if ! command -v wg &> /dev/null; then
    echo "📦 安装WireGuard..."
    apt update
    apt install -y wireguard iptables
fi

# 2. 创建配置目录
mkdir -p /etc/wireguard
cd /etc/wireguard

if [[ "$MODE" == "server" ]]; then
    echo "🏠 配置analytics-engine服务端 (192.168.31.84)"
    
    # 生成服务端密钥
    if [[ ! -f server-private.key ]]; then
        wg genkey | tee server-private.key | wg pubkey > server-public.key
        chmod 600 server-private.key
    fi
    
    SERVER_PRIVATE_KEY=$(cat server-private.key)
    SERVER_PUBLIC_KEY=$(cat server-public.key)
    
    # 创建服务端配置
    cat > wg0.conf << EOF
[Interface]
# analytics-engine服务端配置 (192.168.31.84)
PrivateKey = $SERVER_PRIVATE_KEY
Address = $SERVER_VPN_IP/24
ListenPort = $WG_PORT
SaveConfig = true

# 转发设置 (允许backend访问analytics-engine)
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; echo 1 > /proc/sys/net/ipv4/ip_forward
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# [Peer] 部分需要在backend连接后手动添加
# 或运行: wg set wg0 peer <CLIENT_PUBLIC_KEY> allowed-ips $CLIENT_VPN_IP/32
EOF

    echo "✅ 服务端配置完成"
    echo "📋 服务端公钥: $SERVER_PUBLIC_KEY"
    echo "🔌 请在防火墙中开放UDP端口: $WG_PORT"
    echo ""
    echo "🚀 启动服务:"
    echo "  systemctl enable wg-quick@wg0"
    echo "  systemctl start wg-quick@wg0"
    echo ""
    echo "📝 将此公钥提供给云端backend配置: $SERVER_PUBLIC_KEY"

elif [[ "$MODE" == "client" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "❌ 错误: 需要提供服务器公网IP"
        show_usage
        exit 1
    fi
    
    SERVER_PUBLIC_IP="$2"
    echo "☁️  配置云端backend客户端 -> $SERVER_PUBLIC_IP:$WG_PORT"
    
    # 生成客户端密钥
    if [[ ! -f client-private.key ]]; then
        wg genkey | tee client-private.key | wg pubkey > client-public.key
        chmod 600 client-private.key
    fi
    
    CLIENT_PRIVATE_KEY=$(cat client-private.key)
    CLIENT_PUBLIC_KEY=$(cat client-public.key)
    
    echo "⚠️  需要服务端公钥，请从analytics-engine主机获取"
    echo "📝 请输入服务端公钥:"
    read -r SERVER_PUBLIC_KEY
    
    # 创建客户端配置
    cat > wg0.conf << EOF
[Interface]
# backend客户端配置 (云端)
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_VPN_IP/24

[Peer]
# analytics-engine服务端 (192.168.31.84)
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_PUBLIC_IP:$WG_PORT
AllowedIPs = $SERVER_VPN_IP/32
PersistentKeepalive = 25
EOF

    echo "✅ 客户端配置完成"
    echo "📋 客户端公钥: $CLIENT_PUBLIC_KEY"
    echo ""
    echo "🔧 需要在服务端添加此peer:"
    echo "  wg set wg0 peer $CLIENT_PUBLIC_KEY allowed-ips $CLIENT_VPN_IP/32"
    echo ""
    echo "🚀 启动连接:"
    echo "  systemctl enable wg-quick@wg0" 
    echo "  systemctl start wg-quick@wg0"
    echo ""
    echo "🧮 更新backend环境变量:"
    echo "  ANALYTICS_ENGINE_ENDPOINT=http://$SERVER_VPN_IP:50051"

else
    echo "❌ 错误: 无效模式 '$MODE'"
    show_usage
    exit 1
fi

echo ""
echo "🔍 检查状态: wg show"
echo "🧪 测试连接: ping $SERVER_VPN_IP (从客户端)"
echo "📊 查看日志: journalctl -u wg-quick@wg0 -f"udo cat server-private.key)
SERVER_PUBLIC_KEY=$(sudo cat server-public.key)
CLIENT_PRIVATE_KEY=$(sudo cat client-private.key)
CLIENT_PUBLIC_KEY=$(sudo cat client-public.key)

# 3. 创建服务端配置
echo "📝 创建服务端配置..."
sudo tee wg0.conf << EOF
[Interface]
# 服务端配置 (Analytics Engine主机)
PrivateKey = $SERVER_PRIVATE_KEY
Address = $SERVER_VPN_IP/24
ListenPort = $WG_PORT
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
# 云端Backend客户端
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = $CLIENT_VPN_IP/32
EOF

# 4. 生成客户端配置文件
echo "📝 生成客户端配置..."
sudo tee client-wg0.conf << EOF
[Interface]
# 客户端配置 (云端Backend)
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_VPN_IP/24
DNS = 8.8.8.8

[Peer]
# Analytics Engine服务端
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:$WG_PORT
AllowedIPs = $VPN_NETWORK
PersistentKeepalive = 25
EOF

# 5. 设置权限
sudo chmod 600 /etc/wireguard/*.conf
sudo chmod 600 /etc/wireguard/*.key

# 6. 启用IP转发
echo "🔀 启用IP转发..."
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 7. 启动WireGuard服务
echo "🚀 启动WireGuard服务..."
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

# 8. 防火墙配置
echo "🔥 配置防火墙..."
sudo ufw allow $WG_PORT/udp
sudo ufw allow from $VPN_NETWORK to any port 50051

echo "✅ WireGuard服务端配置完成！"
echo ""
echo "📋 下一步操作："
echo "1. 将客户端配置复制到云端服务器："
echo "   scp /etc/wireguard/client-wg0.conf user@cloud-server:/etc/wireguard/wg0.conf"
echo ""
echo "2. 在云端服务器执行："
echo "   sudo systemctl enable wg-quick@wg0"
echo "   sudo systemctl start wg-quick@wg0"
echo ""
echo "3. 修改backend配置使用VPN地址："
echo "   ANALYTICS_ENDPOINT=http://$SERVER_VPN_IP:50051"
echo ""
echo "🔍 测试连通性："
echo "   ping $SERVER_VPN_IP"
echo "   curl http://$SERVER_VPN_IP:50051/health" 