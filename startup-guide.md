# 🚀 V7项目启动指南

## 📊 **架构概览**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   🌐 Web        │    │   🔗 Envoy      │    │   ⚙️ Backend     │
│   SolidJS       │ ←→ │   gRPC-Web      │ ←→ │   Rust          │
│   Port: 8080    │    │   Gateway       │    │   Port: 50053   │
│                 │    │   Port: 8080    │    │                 │
└─────────────────┘    └─────────────────┘    └─────────┬───────┘
                                                        │
                                               ┌─────────▼───────┐
                                               │  📊 Analytics   │
                                               │  Engine         │
                                               │  Rust gRPC      │
                                               │  Port: 50052    │
                                               └─────────────────┘
```

## 🎯 **通信规则**
- **Web ↔ Backend**: REST + gRPC-Web（通过Envoy）
- **Backend ↔ Analytics**: gRPC直连
- **Web ≠ Analytics**: 禁止直接通信

---

## 🐋 **方案一：完整容器化部署（推荐生产环境）**

### ✅ 优势
- **隔离性强**：每个服务独立运行
- **扩展性好**：可独立扩缩容
- **生产就绪**：接近真实部署环境

### ⚙️ 启动命令
```bash
# 1. 构建所有镜像
podman-compose build

# 2. 启动所有服务
podman-compose up -d

# 3. 查看状态
podman-compose ps
podman-compose logs -f

# 4. 访问应用
# 浏览器：http://localhost:8080
# 控制台测试：testGrpcWeb()
```

### 📊 资源消耗
- **CPU**: ~1.6核心
- **内存**: ~832MB
- **容器数**: 4个

---

## 🏠 **方案二：本地开发模式（推荐开发环境）**

### ✅ 优势  
- **轻量级**：无容器开销
- **调试友好**：直接访问源码
- **快速迭代**：即时热重载

### ⚙️ 启动步骤

#### 1️⃣ 启动Analytics Engine
```bash
cd analytics-engine
./scripts/build.sh
./scripts/run.sh
# 或直接：cargo run --bin analytics-server
```

#### 2️⃣ 启动Backend  
```bash
cd backend
cargo run
# 监听端口：50053 (gRPC)
```

#### 3️⃣ 启动Web（开发模式）
```bash
cd web
npm install
npm run dev
# 开发服务器：http://localhost:3000
```

#### 4️⃣ 启动Envoy（仅容器）
```bash
# 方式1：单独启动Envoy容器
podman run -d \
  --name v7-envoy \
  --network host \
  -v $(pwd)/envoy.yaml:/etc/envoy/envoy.yaml:Z \
  envoyproxy/envoy:v1.29-latest

# 方式2：使用compose仅启动Envoy
podman-compose up -d envoy
```

### 📊 资源消耗
- **CPU**: ~0.8核心
- **内存**: ~400MB  
- **容器数**: 1个（仅Envoy）

---

## 🎭 **方案三：混合模式**

### 🔄 Backend + Analytics容器化，Web本地开发
```bash
# 1. 启动后端服务容器
podman-compose up -d backend analytics-engine envoy

# 2. 本地开发Web
cd web && npm run dev
```

### 🌐 仅Web容器化，Backend本地开发  
```bash
# 1. 本地启动Backend + Analytics
cd analytics-engine && ./scripts/run.sh &
cd backend && cargo run &

# 2. 容器化Web + Envoy
podman-compose up -d web envoy
```

---

## 🔧 **启动脚本修正**

您原来的启动命令存在问题：

❌ **错误版本**：
```bash
cd analytics-engine && python -m uvicorn main:app --port 50052 &
```

✅ **正确版本**：
```bash
# Analytics Engine是Rust服务，不是Python
cd analytics-engine && cargo run --bin analytics-server &
# 或
cd analytics-engine && ./scripts/run.sh &
```

---

## 🎯 **推荐配置**

### 开发阶段
- **使用方案二**：本地开发模式
- 轻量、快速、调试友好

### 测试阶段  
- **使用方案一**：完整容器化
- 接近生产环境

### 生产部署
- **使用方案一** + Kubernetes
- 高可用、可扩展

---

## 🔍 **监控和调试**

### 健康检查
```bash
# Backend健康检查
curl http://localhost:3000/health

# Analytics Engine健康检查  
grpcurl -plaintext localhost:50052 analytics.AnalyticsEngine/HealthCheck

# 通过Envoy的gRPC-Web
curl http://localhost:8080/backend/health
```

### 日志查看
```bash
# 容器日志
podman-compose logs -f backend
podman-compose logs -f analytics-engine

# 本地服务日志
RUST_LOG=debug cargo run  # Backend
RUST_LOG=debug ./scripts/run.sh  # Analytics
```

---

选择最适合您当前需求的方案即可！对于日常开发，推荐**方案二（本地开发模式）**。 