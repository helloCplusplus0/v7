# 📦 Podman-Compose 使用指南

**V7项目Backend+Web容器编排配置使用说明**

---

## 🎯 设计理念

`podman-compose.yml` 专注于**Backend + Web 容器化**，采用混合部署架构：

### ✅ 容器化服务
- 🌐 **Web (nginx + React)**：标准化前端部署
- 🦀 **Backend (Rust FMOD v7)**：API服务容器化

### 🖥️ 原生部署服务  
- 📊 **Analytics Engine (Rust+Python)**：systemd服务部署

### 🔄 为什么Analytics Engine不容器化？

基于实际部署经验的技术决策：

| 问题 | 容器化 | systemd部署 |
|------|--------|-------------|
| **构建复杂度** | ❌ Rust+Python混合困难，600MB镜像 | ✅ 10MB静态二进制 |
| **运行性能** | ❌ 虚拟化开销影响计算性能 | ✅ 原生性能，3-5ms启动 |
| **内存占用** | ❌ 容器基础开销200-300MB | ✅ 实际占用3-5MB |
| **运维复杂度** | ❌ 镜像管理、容器编排 | ✅ 标准Linux服务管理 |
| **依赖管理** | ❌ Python生态容器化复杂 | ✅ 系统包管理器处理 |

---

## 🚀 快速开始

### 1. 环境准备

```bash
# 复制环境变量配置
cp compose.env.example .env

# 根据需要修改配置
vim .env
```

### 2. 混合部署（推荐生产环境）

**Step 1: 部署Analytics Engine (systemd)**
```bash
cd analytics-engine
sudo ./scripts/setup-user.sh    # 创建专用用户
./scripts/build.sh              # 构建二进制
sudo -u analytics ./scripts/deploy.sh  # 部署systemd服务

# 验证Analytics Engine
systemctl status analytics-engine
curl http://localhost:50051/health
```

**Step 2: 启动Backend + Web (容器)**
```bash
# 设置Analytics Engine连接地址
export ANALYTICS_ENGINE_ADDR="http://host.containers.internal:50051"

# 启动容器服务
podman-compose up -d

# 查看服务状态
podman-compose ps
podman-compose logs -f
```

### 3. 验证部署

```bash
# 端到端验证
curl http://localhost:8080/health     # Web前端
curl http://localhost:3000/health     # Backend HTTP
curl http://localhost:50051/health    # Analytics Engine

# 检查服务通信
curl -X POST http://localhost:3000/api/analytics \
  -H "Content-Type: application/json" \
  -d '{"algorithm": "mean", "data": [1,2,3,4,5]}'
```

---

## 🎛️ 部署模式配置

### 模式一：生产环境混合部署

```bash
# .env 配置
ANALYTICS_ENGINE_ADDR=http://host.containers.internal:50051
NODE_ENV=production
RUST_LOG=info

# 部署
cd analytics-engine && sudo -u analytics ./scripts/deploy.sh
podman-compose up -d backend web
```

### 模式二：开发环境本地运行

```bash
# 终端1: Analytics Engine
cd analytics-engine && ./scripts/run.sh

# 终端2: Backend  
cd backend && cargo run

# 终端3: Web开发服务器
cd web && npm run dev
```

### 模式三：测试环境容器化

```bash
# Analytics Engine: 本地进程运行
cd analytics-engine && ./scripts/run.sh &

# Backend + Web: 容器测试
export ANALYTICS_ENGINE_ADDR="http://host.containers.internal:50051"
podman-compose up -d
```

---

## 🔧 配置说明

### 环境变量配置

```bash
# .env 文件配置
# 基础配置
NODE_ENV=production
RUST_LOG=info
TZ=Asia/Shanghai

# 服务端口
BACKEND_HTTP_PORT=3000
BACKEND_GRPC_PORT=50053
WEB_PORT=8080

# Analytics Engine连接（重要）
ANALYTICS_ENGINE_ADDR=http://host.containers.internal:50051

# 镜像配置
BACKEND_IMAGE=v7-backend:latest
WEB_IMAGE=v7-web:latest

# 用户ID配置
BACKEND_UID=1002
BACKEND_GID=1002
WEB_UID=1001
WEB_GID=1001
```

### 网络通信配置

```yaml
# 容器间通信
Backend ↔ Web: 直接容器网络通信
Backend ↔ Analytics: host.containers.internal:50051

# 外部访问
浏览器 → localhost:8080 → Web容器
API调用 → localhost:3000 → Backend容器
```

---

## 📊 服务管理

### 启动服务

```bash
# 启动所有容器服务
podman-compose up -d

# 选择性启动
podman-compose up -d backend    # 仅Backend
podman-compose up -d web        # 仅Web
```

### 查看状态

```bash
# 容器状态
podman-compose ps
podman-compose logs backend
podman-compose logs web

# Analytics Engine状态 (systemd)
systemctl status analytics-engine
journalctl -u analytics-engine -f
```

### 更新部署

```bash
# 更新容器
podman-compose pull
podman-compose up -d --force-recreate

# 更新Analytics Engine
cd analytics-engine
./scripts/build.sh
sudo -u analytics ./scripts/deploy.sh
```

### 停止服务

```bash
# 停止容器
podman-compose down

# 停止Analytics Engine (如果需要)
sudo systemctl stop analytics-engine
```

---

## 🏗️ 架构优势

### ✅ 混合部署优势

1. **性能最优化**：
   - Analytics Engine: 原生性能，无容器开销
   - Backend: 容器化标准化部署
   - Web: nginx高性能静态文件服务

2. **运维简化**：
   - Analytics: 标准systemd服务管理
   - Backend+Web: 统一容器编排
   - 避免复杂的三端容器依赖

3. **扩展灵活**：
   - Analytics可独立扩展到专用计算服务器
   - Backend+Web可水平扩展
   - 服务解耦，独立升级

### 🎯 与完全容器化对比

| 对比项 | 混合部署 | 完全容器化 |
|--------|----------|------------|
| **复杂度** | ⭐⭐ 适中 | ⭐⭐⭐ 复杂 |
| **性能** | ✅ 最优 | ❌ 有损失 |
| **可维护性** | ✅ 分层清晰 | ❌ 依赖复杂 |
| **部署速度** | ✅ 快速 | ❌ 较慢 |
| **资源占用** | ✅ 最小 | ❌ 较大 |

---

## 🚨 常见问题

### Q1: Backend连接Analytics Engine失败
```bash
# 检查Analytics Engine状态
systemctl status analytics-engine

# 检查网络连接
podman exec v7-backend curl http://host.containers.internal:50051/health

# 验证环境变量
podman exec v7-backend env | grep ANALYTICS_ENGINE_ADDR
```

### Q2: 容器启动失败
```bash
# 查看详细错误
podman-compose logs backend
podman-compose logs web

# 检查镜像是否存在
podman images | grep v7

# 重建镜像
podman-compose build --no-cache
```

### Q3: 端口冲突
```bash
# 检查端口占用
sudo netstat -tlnp | grep -E "(3000|8080|50051)"

# 修改端口配置
export WEB_PORT=8081
export BACKEND_HTTP_PORT=3001
podman-compose up -d
```

---

## 📈 性能监控

### 容器资源监控

```bash
# 实时监控
podman stats

# 详细资源使用
podman-compose top
```

### Analytics Engine监控

```bash
# 系统资源
htop -p $(pgrep analytics-server)

# 服务日志
journalctl -u analytics-engine --since "10 minutes ago"
```

---

## 🎉 总结

混合部署架构的核心价值：
- 🚀 **最佳性能**：Analytics Engine原生部署
- 🛠️ **标准化运维**：Backend+Web容器化
- ⚖️ **平衡复杂度**：避免过度容器化
- 🔄 **灵活扩展**：服务独立演进

这种架构既保证了计算密集型服务的性能，又享受了容器化带来的标准化优势！ 