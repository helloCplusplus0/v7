# 📦 FMOD v7 本地 Podman 部署指南

## 🎯 概述

这是一个**极简化**的本地 Podman 部署方案，专为不想处理复杂服务器配置的开发者设计。只需要 Gitea + Podman，即可实现完整的 CI/CD 流程。

## ✨ 特性

- 🚀 **零配置部署**：推送代码自动触发部署
- 🔄 **双环境隔离**：develop → 测试环境，main → 生产环境
- 🐳 **原生容器化**：使用 Podman 轻量级容器
- 💾 **数据持久化**：自动管理数据库存储
- 🔍 **健康监控**：自动验证服务状态

## 🛠️ 系统要求

| 组件 | 要求 | 说明 |
|------|------|------|
| **操作系统** | Ubuntu 20.04+ / CentOS 8+ | 支持 Podman 的 Linux 发行版 |
| **Gitea** | 1.19+ | 需要启用 Actions 功能 |
| **Podman** | 4.0+ | CI 流程会自动安装 |
| **磁盘空间** | 2GB+ | 用于镜像和数据存储 |
| **内存** | 2GB+ | 运行容器的基本要求 |

## 🚀 快速开始

### 1. 克隆项目

```bash
git clone http://192.168.31.84:8081/username/fmod-v7-project.git
cd fmod-v7-project
```

### 2. 初始化 Gitea 仓库

```bash
# 使用自动化脚本
./scripts/gitea-init.sh

# 或手动配置
git remote add origin http://192.168.31.84:8081/username/fmod-v7-project.git
git push -u origin main
```

### 3. 启用 Gitea Actions

1. 在 Gitea 仓库页面，进入 **Settings** → **Actions**
2. 启用 `Repository Actions`
3. 设置权限为 `Allow all actions`

### 4. 开始使用

```bash
# 推送到测试环境
git checkout develop
git push origin develop
# → 自动部署到 http://localhost:5173

# 推送到生产环境
git checkout main  
git push origin main
# → 自动部署到 http://localhost
```

## 📁 项目结构

```
test_project/
├── .gitea/workflows/ci.yml    # 🤖 简化的 CI/CD 配置
├── backend/
│   ├── Dockerfile             # 🐳 后端容器配置
│   └── src/                   # 💻 Rust 源代码
├── web/
│   ├── Dockerfile             # 🐳 前端容器配置  
│   └── src/                   # 🎨 SolidJS 源代码
├── docker-compose.yml         # 📋 容器编排配置
└── scripts/deploy.sh          # 🛠️ 本地部署脚本
```

## 🔄 部署工作流

### 自动化流程

```mermaid
graph LR
    A[推送代码] --> B[代码检查]
    B --> C[运行测试]
    C --> D[构建镜像]
    D --> E[部署容器]
    E --> F[健康检查]
    F --> G[部署完成]
```

### 分支策略

| 分支 | 环境 | 前端端口 | 后端端口 | 自动部署 |
|------|------|----------|----------|----------|
| `develop` | 测试环境 | 5173 | 3001 | ✅ |
| `main` | 生产环境 | 80 | 3000 | ✅ |

## 🐳 容器管理

### 查看运行状态

```bash
# 查看所有 FMOD 相关容器
podman ps | grep fmod

# 详细状态信息
podman stats fmod-frontend-production fmod-backend-production
```

### 容器命名规则

```bash
# 测试环境
fmod-frontend-staging    # 前端测试容器
fmod-backend-staging     # 后端测试容器

# 生产环境  
fmod-frontend-production # 前端生产容器
fmod-backend-production  # 后端生产容器
```

### 常用管理命令

```bash
# 查看日志
podman logs -f fmod-backend-production

# 重启服务
podman restart fmod-frontend-production

# 进入容器
podman exec -it fmod-backend-production /bin/bash

# 查看资源使用
podman stats

# 清理不用的镜像
podman image prune -f
```

## 💾 数据管理

### 数据持久化

```bash
# 查看数据卷
podman volume ls | grep fmod

# 数据卷信息
fmod-data-staging      # 测试环境数据
fmod-data-production   # 生产环境数据
```

### 数据备份

```bash
# 手动备份数据库
podman run --rm \
  -v fmod-data-production:/data:ro \
  -v $(pwd)/backups:/backup \
  alpine:latest \
  cp /data/prod.db /backup/backup-$(date +%Y%m%d-%H%M%S).db

# 查看备份文件
ls -la backups/
```

### 数据恢复

```bash
# 停止服务
podman stop fmod-backend-production

# 恢复数据库
podman run --rm \
  -v fmod-data-production:/data \
  -v $(pwd)/backups:/backup:ro \
  alpine:latest \
  cp /backup/backup-20240101-120000.db /data/prod.db

# 重启服务
podman start fmod-backend-production
```

## 🔧 本地开发

### 开发环境启动

```bash
# 方式一：使用脚本
./scripts/start.sh

# 方式二：分别启动
./scripts/start-backend.sh   # 后端：http://localhost:3000
./scripts/start-frontend.sh  # 前端：http://localhost:5173

# 方式三：使用 npm
npm run dev
```

### 本地容器化测试

```bash
# 本地构建和测试
./scripts/deploy.sh build
./scripts/deploy.sh start

# 查看状态
./scripts/deploy.sh status

# 查看日志
./scripts/deploy.sh logs
```

## 🔍 故障排除

### 常见问题

#### 1. 端口被占用

```bash
# 检查端口占用
sudo netstat -tulpn | grep :80
sudo netstat -tulpn | grep :3000

# 停止冲突的服务
sudo systemctl stop apache2  # 如果 80 端口被占用
sudo systemctl stop nginx    # 如果 80 端口被占用
```

#### 2. 容器启动失败

```bash
# 查看容器日志
podman logs fmod-backend-production

# 检查镜像是否存在
podman images | grep fmod

# 重新构建镜像
podman build -t fmod-backend:latest -f backend/Dockerfile backend/
```

#### 3. 数据库问题

```bash
# 检查数据卷
podman volume inspect fmod-data-production

# 重新创建数据卷
podman volume rm fmod-data-production
podman volume create fmod-data-production
```

#### 4. CI/CD 失败

```bash
# 检查 Gitea Runner 状态
sudo systemctl status gitea-runner

# 查看 Runner 日志
sudo journalctl -u gitea-runner -f

# 重启 Runner
sudo systemctl restart gitea-runner
```

### 调试技巧

```bash
# 查看 CI 构建的镜像
podman images | grep fmod

# 手动运行容器测试
podman run -it --rm fmod-backend:latest /bin/bash

# 查看网络连接
podman network ls
podman inspect fmod-frontend-production | grep -A 10 "NetworkSettings"
```

## 📊 监控和运维

### 性能监控

```bash
# 实时资源使用
podman stats

# 容器健康状态
curl -f http://localhost:3000/health
curl -f http://localhost/health
```

### 日志管理

```bash
# 查看最新日志
podman logs --tail 50 fmod-backend-production

# 跟踪日志
podman logs -f fmod-frontend-production

# 导出日志
podman logs fmod-backend-production > backend.log
```

### 自动化运维

```bash
# 创建定时备份任务
crontab -e
# 添加：0 2 * * * cd /path/to/project && ./scripts/deploy.sh backup

# 创建服务监控脚本
cat > monitor.sh << 'EOF'
#!/bin/bash
if ! curl -sf http://localhost:3000/health > /dev/null; then
  echo "Backend service down, restarting..."
  podman restart fmod-backend-production
fi
EOF
chmod +x monitor.sh
```

## 🌐 网络配置

### 端口映射

| 服务 | 容器端口 | 主机端口 | 说明 |
|------|----------|----------|------|
| 前端（测试） | 80 | 5173 | 测试环境前端 |
| 前端（生产） | 80 | 80 | 生产环境前端 |
| 后端（测试） | 3000 | 3001 | 测试环境API |
| 后端（生产） | 3000 | 3000 | 生产环境API |

### 访问地址

```bash
# 测试环境
echo "前端: http://localhost:5173"
echo "后端: http://localhost:3001"

# 生产环境
echo "前端: http://localhost"
echo "后端: http://localhost:3000"
```

## 🔄 升级和维护

### 版本升级

```bash
# 拉取最新代码
git pull origin main

# 重新部署
./scripts/deploy.sh deploy

# 或推送触发自动部署
git push origin main
```

### 清理维护

```bash
# 清理不用的镜像
podman image prune -f

# 清理停止的容器
podman container prune -f

# 清理不用的数据卷（谨慎使用）
podman volume prune -f
```

## 📚 相关资源

- 📖 [Podman 官方文档](https://podman.io/docs)
- 🔧 [部署脚本详解](../scripts/deploy.sh)
- 🏗️ [Docker Compose 配置](../docker-compose.yml)
- ⚙️ [CI/CD 配置说明](../.gitea/workflows/ci.yml)

---

## 🎯 总结

这个简化的本地 Podman 部署方案具有以下优势：

- ✅ **简单易用**：无需复杂的服务器配置
- ✅ **自动化程度高**：推送代码即部署
- ✅ **环境隔离**：测试和生产环境完全独立
- ✅ **资源轻量**：Podman 比 Docker 更轻量
- ✅ **安全性好**：无需 root 权限运行
- ✅ **易于维护**：标准化的容器管理

**适用场景**：
- 个人项目或小团队开发
- 快速原型验证
- 学习 DevOps 实践
- 本地开发环境

**现在您可以专注于业务代码开发，而不是复杂的运维配置！** 🚀 