# 🚀 V7 轻量化部署指南

## 📋 概述

V7项目采用轻量化部署策略，避免复杂的CI/CD配置，专注于快速、稳定的镜像构建和部署流程。

## 🏗️ 整体架构

```
📦 开发环境 (192.168.31.84)    ☁️ 云服务器 (2核2GB)
┌─────────────────────────┐    ┌────────────────────────────┐
│ 🔧 开发和构建            │    │ 🚀 生产运行                │
│ ├─ Backend开发          │    │ ├─ Backend容器              │
│ ├─ Web开发              │    │ ├─ Web容器                 │
│ ├─ Analytics Engine     │ ───┤ └─ WireGuard VPN连接      │
│ └─ 镜像构建             │    │                            │
└─────────────────────────┘    └────────────────────────────┘
```

## 🎯 部署策略选择

### ✅ 推荐方案：镜像注册表 + 远程脚本

**优势**：
- 🚀 **快速部署**：只需一条命令完成部署
- 📦 **镜像复用**：构建一次，多次部署
- 🔄 **版本管理**：支持版本回滚和灰度发布
- 🛠️ **简化运维**：减少服务器存储和维护负担
- 🔒 **安全性**：不暴露源代码到生产服务器

**流程**：
```
开发环境构建 → GitHub Registry → 云服务器拉取部署
```

## 📋 部署准备

### 1. 开发环境准备
```bash
# 安装必要工具
sudo apt-get install -y podman git curl

# 检查项目结构
ls -la
# 确保存在：
# ├── backend/Dockerfile
# ├── web/Dockerfile
# ├── podman-compose.yml
# └── scripts/
```

### 2. GitHub设置
```bash
# 创建GitHub Personal Access Token
# 权限：packages:write, packages:read

# 测试登录
echo "YOUR_TOKEN" | podman login ghcr.io --username YOUR_USERNAME --password-stdin
```

### 3. 云服务器准备
```bash
# 安装podman和podman-compose
sudo apt-get update
sudo apt-get install -y podman podman-compose curl git

# 确保端口开放
sudo ufw allow 3000/tcp  # Backend API
sudo ufw allow 8080/tcp  # Web服务
```

## 🚀 部署流程

### 阶段一：本地构建和推送

```bash
# 1. 构建镜像（仅本地测试）
./scripts/build-and-push.sh

# 2. 构建并推送到GitHub Registry
./scripts/build-and-push.sh --push \
  -u YOUR_GITHUB_USERNAME \
  -t YOUR_GITHUB_TOKEN

# 3. 指定版本构建
./scripts/build-and-push.sh --push \
  -v v1.0.0 \
  -u YOUR_GITHUB_USERNAME \
  -t YOUR_GITHUB_TOKEN
```

### 阶段二：云服务器部署

```bash
# 方法1：直接下载并执行
curl -sSL https://raw.githubusercontent.com/YOUR_ORG/v7/main/scripts/remote-deploy.sh | bash -s -- \
  -B ghcr.io/YOUR_ORG/v7/backend:latest \
  -W ghcr.io/YOUR_ORG/v7/web:latest \
  -u YOUR_GITHUB_USERNAME \
  -t YOUR_GITHUB_TOKEN

# 方法2：下载后配置执行
wget https://raw.githubusercontent.com/YOUR_ORG/v7/main/scripts/remote-deploy.sh
chmod +x remote-deploy.sh

./remote-deploy.sh \
  -r https://github.com/YOUR_ORG/v7.git \
  -B ghcr.io/YOUR_ORG/v7/backend:v1.0.0 \
  -W ghcr.io/YOUR_ORG/v7/web:v1.0.0 \
  -u YOUR_GITHUB_USERNAME \
  -t YOUR_GITHUB_TOKEN
```

### 阶段三：验证和测试

```bash
# 检查服务状态
cd /opt/v7-deploy
podman-compose ps

# 查看日志
podman-compose logs -f

# 健康检查
curl http://localhost:3000/health  # Backend
curl http://localhost:8080/        # Web

# 测试完整链路（如果已配置WireGuard）
# 注意：需要先设置WireGuard VPN连接到analytics-engine
```

## 🔧 高级配置

### 1. 环境变量定制

```bash
# 在云服务器上修改 /opt/v7-deploy/.env
vim /opt/v7-deploy/.env

# 关键配置项：
ANALYTICS_ENGINE_ENDPOINT=http://10.0.0.1:50051  # WireGuard VPN地址
DATABASE_URL=sqlite:/app/data/prod.db
JWT_SECRET=your-production-secret
```

### 2. 版本回滚

```bash
# 回滚到上一个版本
./remote-deploy.sh \
  -B ghcr.io/YOUR_ORG/v7/backend:v1.0.0 \
  -W ghcr.io/YOUR_ORG/v7/web:v1.0.0

# 查看可用版本
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://ghcr.io/v2/YOUR_ORG/v7/backend/tags/list
```

### 3. 灰度发布

```bash
# 1. 部署新版本到测试端口
BACKEND_HTTP_PORT=3001 WEB_PORT=8081 ./remote-deploy.sh \
  -B ghcr.io/YOUR_ORG/v7/backend:v1.1.0 \
  -W ghcr.io/YOUR_ORG/v7/web:v1.1.0

# 2. 验证新版本
curl http://localhost:3001/health

# 3. 切换流量（使用负载均衡器或手动切换）
```

## 🔍 故障排除

### 1. 镜像拉取失败
```bash
# 检查登录状态
podman login ghcr.io --get-login

# 重新登录
echo "YOUR_TOKEN" | podman login ghcr.io --username YOUR_USERNAME --password-stdin

# 手动拉取测试
podman pull ghcr.io/YOUR_ORG/v7/backend:latest
```

### 2. 服务启动失败
```bash
# 查看详细日志
podman logs v7-backend --tail=50
podman logs v7-web --tail=50

# 检查端口占用
netstat -tlnp | grep -E ":3000|:8080"

# 检查磁盘空间
df -h /
```

### 3. Analytics Engine连接问题
```bash
# 检查WireGuard状态
sudo wg show

# 测试网络连通性
ping 10.0.0.1  # WireGuard VPN地址
curl http://10.0.0.1:50051/health  # Analytics Engine健康检查

# 检查防火墙
sudo ufw status
```

## 📊 性能监控

### 1. 资源使用监控
```bash
# 容器资源监控
podman stats --no-stream

# 系统资源监控
htop
free -h
df -h
```

### 2. 服务健康监控
```bash
# 创建监控脚本
cat > /opt/v7-deploy/monitor.sh << 'EOF'
#!/bin/bash
while true; do
  if ! curl -f http://localhost:3000/health > /dev/null 2>&1; then
    echo "$(date): Backend health check failed" >> /var/log/v7-monitor.log
  fi
  if ! curl -f http://localhost:8080/ > /dev/null 2>&1; then
    echo "$(date): Web health check failed" >> /var/log/v7-monitor.log
  fi
  sleep 60
done
EOF

chmod +x /opt/v7-deploy/monitor.sh

# 运行监控（可选：添加到systemd）
nohup /opt/v7-deploy/monitor.sh &
```

## 🎯 最佳实践

### 1. 版本管理
- 🏷️ 使用语义化版本标签（v1.0.0, v1.1.0）
- 🔄 保持latest标签指向稳定版本
- 📦 定期清理旧版本镜像以节省空间

### 2. 安全建议
- 🔐 定期轮换GitHub Token
- 🔒 使用只读权限的部署Token
- 🛡️ 配置防火墙只开放必要端口
- 📝 定期备份数据库和配置文件

### 3. 运维建议
- 📊 设置基础监控和告警
- 💾 定期备份重要数据
- 🔄 制定故障恢复计划
- 📖 维护部署文档和变更记录

## 📞 获取帮助

如果遇到问题，可以：

1. **查看日志**：`podman-compose logs -f`
2. **检查脚本帮助**：`./scripts/remote-deploy.sh --help`
3. **查看GitHub Issues**：项目仓库的Issues页面
4. **检查文档**：[WireGuard部署指南](./WIREGUARD_DEPLOYMENT_GUIDE.md)

---

**记住：简单的方案往往是最可靠的方案。这个轻量化部署流程专注于核心功能，避免了过度复杂的自动化配置。** 