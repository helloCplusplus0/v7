# 🚀 Analytics Engine 部署指南

> **完整的生产部署和运维管理指南**  
> 项目介绍和开发指南请参考：[README.md](../README.md)

## 📋 部署策略

Analytics Engine采用**systemd服务部署**，放弃容器化方案。

### 🎯 为什么选择systemd而非容器？

经过深入分析，我们决定采用systemd服务部署：

✅ **极致性能**：无容器虚拟化开销，静态二进制直接运行  
✅ **简单运维**：标准Linux服务管理，无需学习容器编排  
✅ **资源效率**：内存占用仅3-5MB，容器至少增加200MB  
✅ **稳定可靠**：systemd久经考验，自动重启、依赖管理  
✅ **高效工作流**：保持`./scripts/build.sh + ./scripts/run.sh`的简洁流程

### ❌ 容器化的问题

- **资源浪费**：200-300MB镜像 vs 10MB静态二进制
- **复杂度增加**：破坏了简单高效的开发工作流
- **性能损失**：虚拟化层开销对计算密集型服务不友好
- **运维复杂**：容器编排、镜像管理增加运维负担

---

## 🎯 三种部署场景

| 场景 | 适用情况 | 复杂度 | 命令 |
|------|----------|--------|------|
| **开发模式** | 本地开发测试 | ⭐ | `./scripts/run.sh` |
| **单服务器** | Web+Backend+Analytics同机部署 | ⭐⭐ | `./scripts/deploy.sh` |
| **跨服务器** | Analytics独立部署到计算服务器 | ⭐⭐⭐ | `./scripts/deploy.sh --remote` |

## 🎯 场景一：开发模式（推荐新手）

```bash
cd analytics-engine

# 一键构建和运行
./scripts/build.sh && ./scripts/run.sh

# 验证服务
curl http://localhost:50051/health
```

**特点**：
- ✅ 最简单，无需root权限
- ✅ 适合开发调试
- ❌ 重启后服务不会自动启动

## 🎯 场景二：单服务器部署（推荐生产）

```bash
# Step 1: 创建专用用户
sudo ./scripts/setup-user.sh

# Step 2: 构建和部署
./scripts/build.sh
sudo -u analytics ./scripts/deploy.sh

# Step 3: 管理服务
./scripts/manage-service.sh
```

**部署架构**：
```
单台云服务器
├── Web (nginx) - Port 80
├── Backend (rust) - Port 50053  
└── Analytics (systemd) - Port 50051
    ├── 用户: analytics
    ├── 路径: /opt/v7/analytics-engine
    └── 通信: localhost:50051
```

**特点**：
- ✅ 生产级部署，systemd管理
- ✅ 开机自启，自动重启
- ✅ 专用用户，安全隔离
- ✅ 适合Web+Backend+Analytics同机部署

## 🎯 场景三：跨服务器部署（企业级）

### 三种部署模式详解

#### **模式一：本地部署（仅localhost访问）**
```bash
sudo -u analytics ./scripts/deploy.sh
```

**配置**：
- 监听地址：`127.0.0.1:50051`（仅本地回环）
- 防火墙：不开放外部端口
- 适用：Web+Backend+Analytics同机部署

#### **模式二：本地部署+远程访问**
```bash
sudo -u analytics ./scripts/deploy.sh --enable-remote
```

**配置**：
- 监听地址：`0.0.0.0:50051`（监听所有网络接口）
- 防火墙：自动开放50051端口
- 适用：需要跨服务器通信但Analytics在本地

#### **模式三：远程服务器部署**
```bash
./scripts/deploy.sh --remote-host 192.168.1.100
```

**配置**：
- 部署位置：远程服务器（192.168.1.100）
- 通过SSH上传构建文件并在远程服务器部署
- 适用：Analytics独立部署到计算服务器

### SSH配置要求（模式三）

```bash
# 1. 配置SSH密钥访问
ssh-copy-id root@192.168.1.100

# 2. 测试SSH连接
ssh root@192.168.1.100 "echo 'Connection successful'"
```

### 部署架构对比

**同机部署（模式一）**：
```
云服务器A
┌─────────────────────────┐
│ Web + Backend + Analytics│
│ 通信: localhost:50051    │
└─────────────────────────┘
```

**跨服务器部署（模式三）**：
```
云服务器A (Web+Backend)      云服务器B (Analytics)
┌─────────────────────────┐   ┌─────────────────────────┐
│ Web + Backend           │   │ Analytics Engine        │
│ ANALYTICS_ENGINE_ADDR=  │───┼──→ systemd service      │
│ B-SERVER-IP:50051       │   │ Port: 50051             │
└─────────────────────────┘   └─────────────────────────┘
```

---

## 🔧 核心脚本说明

| 脚本 | 用途 | 使用场景 |
|------|------|----------|
| `build.sh` | 构建二进制文件 | 所有场景必需 |
| `run.sh` | 开发模式运行 | 开发调试 |
| `setup-user.sh` | 创建analytics用户 | 生产部署必需 |
| `deploy.sh` | 生产部署 | 单服务器/跨服务器 |
| `manage-service.sh` | 服务管理 | 运维管理 |

### 脚本关系
```
开发流程: build.sh → run.sh
生产流程: setup-user.sh → build.sh → deploy.sh → manage-service.sh
```

### 详细使用说明

更多脚本使用说明请参考：[scripts/README.md](README.md)

---

## 📝 日常运维

### 服务管理
```bash
# 友好的图形界面
./scripts/manage-service.sh

# 或直接systemctl命令
sudo systemctl {start|stop|restart|status} analytics-engine
```

### 监控检查
```bash
# 健康检查
curl -f http://localhost:50051/health
grpcurl -plaintext localhost:50051 analytics.AnalyticsEngine/HealthCheck

# 查看日志
sudo journalctl -u analytics-engine -f

# 性能监控
htop -p $(pgrep analytics-server)
```

### 更新部署
```bash
# 重新构建
./scripts/build.sh

# 热更新部署
sudo -u analytics ./scripts/deploy.sh
```

---

## 🚨 故障排除

### 权限问题
```bash
# 确保analytics用户存在
sudo ./scripts/setup-user.sh

# 检查文件权限
ls -la /opt/v7/analytics-engine/
```

### 服务无法启动
```bash
# 查看详细错误
sudo journalctl -u analytics-engine -n 50

# 检查二进制文件
/opt/v7/analytics-engine/bin/analytics-server --version
```

### 网络连接问题
```bash
# 检查端口监听
sudo netstat -tlnp | grep 50051

# 测试gRPC连接
grpcurl -plaintext localhost:50051 analytics.AnalyticsEngine/HealthCheck
```

### Python模块问题
```bash
# 检查Python路径
sudo -u analytics /opt/v7/analytics-engine/bin/analytics-server --test-python
```

### 常见错误解决

#### 错误：`Permission denied`
```bash
# 检查用户和权限
sudo ./scripts/setup-user.sh
sudo chown -R analytics:analytics /opt/v7/analytics-engine/
```

#### 错误：`Address already in use`
```bash
# 查找占用端口的进程
sudo netstat -tlnp | grep 50051
sudo kill -9 <PID>
```

#### 错误：`Python module not found`
```bash
# 重新安装Python依赖
cd analytics-engine && pip install -r requirements.txt
```

---

## 🔒 安全最佳实践

### 用户权限
- ✅ **analytics专用用户**：运行服务，最小权限
- ✅ **sudo用户**：管理和部署操作
- ✅ **权限隔离**：服务无法访问其他系统资源

### 网络安全
```bash
# 同服务器部署（推荐）
ANALYTICS_ENGINE_ADDR=localhost:50051  # 无需开放外部端口

# 跨服务器部署（按需）
sudo ufw allow 50051/tcp  # 仅限内网访问
```

### 文件安全
```bash
# 检查关键权限
ls -la /opt/v7/analytics-engine/bin/analytics-server  # 755, owned by analytics
ls -la /etc/systemd/system/analytics-engine.service   # 644, owned by root
```

---

## 📊 性能优化

### 系统资源
- **CPU**: 2-4核（单服务器）/ 4-8核（专用服务器）
- **内存**: 4-8GB（含Python ML库）
- **存储**: 20-50GB
- **网络**: 1Gbps+（跨服务器通信）

### systemd配置调优
```bash
# 编辑systemd服务
sudo systemctl edit analytics-engine

# 添加资源限制
[Service]
MemoryMax=4G
TasksMax=8192
LimitNOFILE=65536
```

---

## 🔄 备份和恢复

### 备份重要数据
```bash
sudo tar -czf analytics-backup-$(date +%Y%m%d).tar.gz \
  /opt/v7/analytics-engine/ \
  /etc/systemd/system/analytics-engine.service
```

### 恢复步骤
```bash
sudo tar -xzf analytics-backup-20240315.tar.gz -C /
sudo systemctl daemon-reload
sudo systemctl start analytics-engine
```

---

## 🎉 总结

### 推荐路径
1. **开发阶段**：使用`run.sh`快速验证功能
2. **测试阶段**：使用单服务器部署验证完整流程
3. **生产阶段**：根据负载选择单服务器或跨服务器

### 核心优势
- 🚀 **高性能**：原生二进制，无容器开销
- 🔒 **安全性**：专用用户，权限隔离
- 🛠️ **简单性**：标准systemd，统一管理
- 🔄 **可靠性**：自动重启，健康检查

**记住**：选择最简单满足需求的部署方式，不要过度复杂化！ 