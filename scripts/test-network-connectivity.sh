#!/bin/bash

# 🌐 网络连接诊断脚本
# 用于排查GHCR连接问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
step() { echo -e "${BLUE}🔧 $1${NC}"; }

echo "🌐 网络连接诊断工具"
echo "===================="
echo ""

# 1. 基础网络检查
step "检查基础网络连接..."
echo ""

# 检查DNS解析
info "1. DNS解析测试"
if nslookup github.com >/dev/null 2>&1; then
    log "DNS解析正常 - github.com"
else
    error "DNS解析失败 - github.com"
    echo "建议检查 /etc/resolv.conf 配置"
fi

if nslookup ghcr.io >/dev/null 2>&1; then
    log "DNS解析正常 - ghcr.io"
else
    error "DNS解析失败 - ghcr.io"
fi

echo ""

# 检查网络连通性
info "2. 网络连通性测试"
if ping -c 3 8.8.8.8 >/dev/null 2>&1; then
    log "网络连通性正常 - Google DNS"
else
    error "网络连通性异常 - 无法访问外网"
fi

if ping -c 3 github.com >/dev/null 2>&1; then
    log "网络连通性正常 - GitHub"
else
    error "网络连通性异常 - 无法访问GitHub"
fi

echo ""

# 检查HTTP/HTTPS连接
info "3. HTTP/HTTPS连接测试"
if curl -I --connect-timeout 10 https://www.github.com >/dev/null 2>&1; then
    log "HTTPS连接正常 - GitHub"
else
    error "HTTPS连接失败 - GitHub"
fi

if curl -I --connect-timeout 10 https://ghcr.io >/dev/null 2>&1; then
    log "HTTPS连接正常 - GHCR"
else
    error "HTTPS连接失败 - GHCR"
    warn "这可能是防火墙或代理问题"
fi

echo ""

# 2. 详细网络信息
step "收集网络配置信息..."
echo ""

info "网络接口信息:"
ip addr show | grep -E "(inet |UP|DOWN)" | head -10

echo ""
info "路由表信息:"
ip route | head -5

echo ""
info "DNS配置:"
cat /etc/resolv.conf | grep -v "^#" | head -5

echo ""

# 3. 防火墙检查
step "检查防火墙配置..."
echo ""

info "UFW防火墙状态:"
if command -v ufw >/dev/null 2>&1; then
    sudo ufw status || echo "无法获取UFW状态"
else
    warn "UFW未安装"
fi

echo ""
info "iptables规则 (前10条):"
sudo iptables -L -n | head -15 || echo "无法获取iptables规则"

echo ""

# 4. 代理检查
step "检查代理配置..."
echo ""

info "环境变量代理:"
env | grep -i proxy || warn "未设置代理环境变量"

echo ""

# 5. 容器网络检查
step "检查容器网络..."
echo ""

info "Podman网络列表:"
podman network ls || warn "无法获取Podman网络信息"

echo ""
info "Podman系统信息:"
podman system info | grep -E "(network|dns)" || warn "无法获取Podman系统信息"

echo ""

# 6. 云服务商特殊检查
step "检查云服务商网络限制..."
echo ""

info "检查是否为云服务器:"
if curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/ >/dev/null 2>&1; then
    warn "检测到AWS EC2实例"
    echo "请检查安全组设置，确保允许HTTPS出站连接"
elif curl -s --connect-timeout 5 http://100.100.100.200/latest/meta-data/ >/dev/null 2>&1; then
    warn "检测到阿里云ECS实例"
    echo "请检查安全组设置，确保允许HTTPS出站连接"
elif curl -s --connect-timeout 5 http://169.254.0.23/computeMetadata/v1/ >/dev/null 2>&1; then
    warn "检测到Google Cloud实例"
    echo "请检查防火墙规则，确保允许HTTPS出站连接"
else
    info "未检测到常见云服务商元数据"
fi

echo ""

# 7. 修复建议
step "网络问题修复建议..."
echo ""

echo "🔧 常见解决方案："
echo ""
echo "1. DNS问题修复："
echo "   sudo echo 'nameserver 8.8.8.8' >> /etc/resolv.conf"
echo "   sudo echo 'nameserver 1.1.1.1' >> /etc/resolv.conf"
echo ""
echo "2. 防火墙配置："
echo "   sudo ufw allow out 443/tcp  # 允许HTTPS出站"
echo "   sudo ufw allow out 80/tcp   # 允许HTTP出站"
echo ""
echo "3. 代理配置（如果需要）："
echo "   export https_proxy=http://proxy-server:port"
echo "   export http_proxy=http://proxy-server:port"
echo ""
echo "4. 云服务商安全组："
echo "   - 确保出站规则允许443端口（HTTPS）"
echo "   - 确保出站规则允许80端口（HTTP）"
echo "   - 检查是否有网络ACL限制"
echo ""
echo "5. 重启网络服务："
echo "   sudo systemctl restart systemd-networkd"
echo "   sudo systemctl restart systemd-resolved"
echo ""

# 8. 快速测试命令
echo "🧪 快速测试命令："
echo ""
echo "测试GHCR连接："
echo "curl -v https://ghcr.io/v2/"
echo ""
echo "测试GitHub连接："
echo "curl -v https://api.github.com"
echo ""
echo "测试DNS解析："
echo "dig ghcr.io"
echo ""

log "网络诊断完成！"
echo ""
echo "💡 如果问题仍然存在，请："
echo "1. 联系云服务商技术支持"
echo "2. 检查企业网络策略"
echo "3. 考虑使用VPN或代理" 