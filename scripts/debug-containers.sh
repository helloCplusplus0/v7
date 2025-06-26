#!/bin/bash

# 🐛 容器调试脚本
# 用于排查容器运行问题

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

echo "🐛 容器调试工具"
echo "================"
echo ""

# 1. 检查所有容器状态
step "检查所有容器状态..."
echo ""
info "运行中的容器:"
podman ps

echo ""
info "所有容器（包括停止的）:"
podman ps -a

echo ""

# 2. 检查容器日志
step "检查容器日志..."
echo ""

info "后端容器日志 (最近50行):"
echo "------------------------"
podman logs --tail=50 v7-backend 2>/dev/null || warn "无法获取后端容器日志"

echo ""
info "前端容器日志 (最近50行):"
echo "------------------------"
podman logs --tail=50 v7-web 2>/dev/null || warn "前端容器可能不存在或已停止"

echo ""

# 3. 检查容器详细信息
step "检查容器详细信息..."
echo ""

info "后端容器详细信息:"
podman inspect v7-backend --format '{{.State.Status}}: {{.State.Error}}' 2>/dev/null || warn "无法获取后端容器信息"

info "前端容器详细信息:"
podman inspect v7-web --format '{{.State.Status}}: {{.State.Error}}' 2>/dev/null || warn "前端容器不存在"

echo ""

# 4. 检查网络连接
step "检查容器网络..."
echo ""

info "容器网络列表:"
podman network ls

echo ""
info "检查端口占用:"
netstat -tlnp | grep -E ":(3000|8080|9100)" || warn "相关端口未被占用"

echo ""

# 5. 检查资源使用
step "检查系统资源..."
echo ""

info "内存使用情况:"
free -h

echo ""
info "磁盘使用情况:"
df -h

echo ""
info "CPU负载:"
uptime

echo ""

# 6. 尝试手动启动容器
step "尝试手动诊断..."
echo ""

info "检查镜像是否存在:"
podman images | grep -E "(backend|web)" || warn "找不到相关镜像"

echo ""

# 7. 提供修复建议
step "修复建议..."
echo ""

echo "🔧 常见问题排查步骤："
echo ""
echo "1. 重启失败的容器:"
echo "   podman restart v7-backend"
echo "   podman restart v7-web"
echo ""
echo "2. 查看详细启动日志:"
echo "   podman logs -f v7-backend"
echo "   podman logs -f v7-web"
echo ""
echo "3. 检查容器配置:"
echo "   podman inspect v7-backend"
echo "   podman inspect v7-web"
echo ""
echo "4. 重新部署服务:"
echo "   cd /home/deploy/containers/v7-project"
echo "   podman-compose down"
echo "   podman-compose up -d"
echo ""
echo "5. 清理并重建:"
echo "   podman-compose down --volumes"
echo "   podman system prune -f"
echo "   podman-compose up -d"
echo ""

# 8. 健康检查
step "执行健康检查..."
echo ""

info "测试后端健康状态:"
if curl -f -s http://localhost:3000/health >/dev/null 2>&1; then
    log "后端服务正常响应"
else
    error "后端服务无响应"
fi

info "测试前端健康状态:"
if curl -f -s http://localhost:8080/health >/dev/null 2>&1; then
    log "前端服务正常响应"
else
    error "前端服务无响应"
fi

echo ""
log "容器调试完成！"
echo ""
echo "💡 如果问题仍然存在："
echo "1. 检查应用程序配置"
echo "2. 检查数据库连接"
echo "3. 检查文件权限"
echo "4. 考虑重启服务器" 