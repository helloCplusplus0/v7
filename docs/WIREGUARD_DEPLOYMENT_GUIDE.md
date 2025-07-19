# 🔐 WireGuard + 容器化部署完整指南

## 🎯 **部署架构总览**

```
☁️ 云端环境                          🔐 WireGuard VPN                    🏠 本地环境(192.168.31.84)
┌─────────────────────────┐          ┌───────────────────┐                ┌──────────────────────────┐
│ podman(backend) host网络 │ ←────────│ 加密隧道 51820/udp │────────────→  │ analytics-engine systemd │
│ ├─直接访问主机网络栈      │          │                   │                │ 10.0.0.1:50051          │
│ └─可访问WireGuard(wg0)  │          │                   │                │                          │
│ podman(web) bridge网络  │          │                   │                │                          │
└─────────────────────────┘          └───────────────────┘                └──────────────────────────┘
```

## 📋 **部署步骤总览**

### 阶段1：本地准备 (192.168.31.84)
1. 配置WireGuard服务端
2. 部署analytics-engine (systemd)
3. 测试本地连接

### 阶段2：云端部署
1. 配置WireGuard客户端  
2. 容器化部署backend+web
3. 验证VPN连接通信

---

## 🏠 **阶段1：本地环境配置**

### Step 1: WireGuard服务端配置

```bash
# 在本地主机(192.168.31.84)执行
cd backend
sudo ./scripts/setup-wireguard.sh server

# 记录生成的公钥，供云端配置使用
sudo cat /etc/wireguard/server-public.key
```

### Step 2: Analytics Engine部署

```bash
# 部署analytics-engine为systemd服务
cd analytics-engine
sudo ./scripts/setup-user.sh
./scripts/build.sh
sudo -u analytics ./scripts/deploy.sh

# 验证服务
systemctl status analytics-engine
curl http://127.0.0.1:50051/health
```

### Step 3: WireGuard服务启动

```bash
# 启动WireGuard服务端
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

# 验证VPN接口
sudo wg show
ip addr show wg0
```

---

## ☁️ **阶段2：云端环境部署**

### Step 1: WireGuard客户端配置

```bash
# 在云端服务器执行
cd backend
sudo ./scripts/setup-wireguard.sh client <本地公网IP>

# 输入本地服务端公钥（从阶段1获得）
# 记录生成的客户端公钥

# 启动WireGuard客户端
sudo systemctl enable wg-quick@wg0  
sudo systemctl start wg-quick@wg0

# 验证连接
ping 10.0.0.1  # 本地analytics-engine VPN IP
curl http://10.0.0.1:50051/health
```

### Step 2: 更新本地WireGuard配置

```bash
# 在本地主机(192.168.31.84)添加客户端peer
sudo wg set wg0 peer <云端客户端公钥> allowed-ips 10.0.0.2/32

# 保存配置  
sudo wg-quick save wg0
```

### Step 3: 容器化部署

```bash
# 在云端服务器配置环境变量
cat > .env << EOF
# Analytics Engine通过WireGuard VPN连接
ANALYTICS_ENGINE_ADDR=http://host.containers.internal:50051

# Backend配置
BACKEND_IMAGE=v7-backend:latest
BACKEND_HTTP_PORT=3000
BACKEND_GRPC_PORT=50053

# Web配置  
WEB_IMAGE=v7-web:latest
WEB_PORT=8080

# 环境配置
NODE_ENV=production
RUST_LOG=info
EOF

# 启动容器服务
podman-compose up -d

# 验证部署
podman-compose ps
podman-compose logs -f backend
```

---

## 🧪 **通信验证流程**

### 1. VPN连接验证

```bash
# 云端 → 本地VPN连接
ping 10.0.0.1

# 本地 → 云端VPN连接  
ping 10.0.0.2
```

### 2. Analytics Engine连接验证

```bash
# 在云端服务器执行
curl http://10.0.0.1:50051/health

# 预期响应
{
  "healthy": true,
  "version": "1.0.0",
  "capabilities": {...}
}
```

### 3. 端到端业务验证

```bash
# Backend → Analytics Engine 通信测试
curl -X POST http://localhost:3000/api/analytics \
  -H "Content-Type: application/json" \
  -d '{
    "algorithm": "statistics", 
    "data": [1,2,3,4,5]
  }'

# 预期：返回统计分析结果
```

### 4. Web前端验证

```bash
# 访问Web应用
curl http://localhost:8080/health

# 浏览器访问
# http://<云端服务器IP>:8080
```

---

## 🔧 **配置文件详解**

### backend环境配置

```bash
# backend/dev.env (开发环境)
ANALYTICS_ENGINE_ENDPOINT=http://127.0.0.1:50051

# backend容器环境变量 (生产环境)
ANALYTICS_ENGINE_ADDR=http://host.containers.internal:50051
```

### podman-compose.yml关键配置

```yaml
services:
  backend:
    environment:
      # VPN场景：容器通过主机网络栈访问WireGuard
      - ANALYTICS_ENGINE_ADDR=http://host.containers.internal:50051
    
    # 健康检查适配VPN延迟
    healthcheck:
      timeout: 15s      # VPN可能增加延迟
      retries: 5        # 应对VPN连接波动
      start_period: 45s # 等待VPN连接建立
```

---

## 🛠️ **故障排查指南**

### VPN连接问题

```bash
# 检查WireGuard状态
sudo wg show

# 检查路由表
ip route show table all | grep wg0

# 检查防火墙
sudo ufw status
sudo iptables -L -n | grep wg0
```

### Analytics Engine连接问题

```bash
# 检查VPN网络连通性
ping 10.0.0.1

# 检查端口监听
netstat -tlpn | grep 50051

# 检查服务状态
systemctl status analytics-engine
```

### Backend容器连接问题

```bash
# 检查容器网络
podman exec v7-backend ip route

# 检查DNS解析
podman exec v7-backend nslookup host.containers.internal

# 检查连接日志
podman logs v7-backend | grep analytics
```

---

## 📊 **性能对比**

| 连接方式 | 延迟 | 吞吐量 | 安全性 | 复杂度 |
|----------|------|--------|--------|--------|
| 直连 | 1-3ms | 1Gbps+ | ❌ 低 | ⭐ 简单 |
| WireGuard VPN | 5-15ms | 500Mbps+ | ✅ 高 | ⭐⭐⭐ 中等 |
| 隧道代理 | 20-50ms | 100Mbps | ⚠️ 中 | ⭐⭐⭐⭐ 复杂 |

**结论**：WireGuard在安全性和性能之间取得最佳平衡。

---

## 🎯 **最佳实践建议**

### 开发阶段
- **建议**：使用本地直连 (127.0.0.1:50051)
- **原因**：最快的迭代速度，无网络复杂性

### 测试阶段  
- **建议**：模拟生产环境，配置WireGuard
- **原因**：验证网络通信的稳定性和延迟影响

### 生产部署
- **必须**：使用WireGuard VPN + 严格防火墙规则
- **原因**：确保数据传输安全，符合企业安全标准

---

## 🔐 **安全检查清单**

- [ ] WireGuard使用强加密算法(ChaCha20/Poly1305)
- [ ] 定期轮换WireGuard密钥对(建议每季度)
- [ ] 防火墙仅开放必要端口(51820/udp, 50051/tcp)
- [ ] 监控VPN连接日志和异常活动
- [ ] 备份WireGuard配置文件并加密存储
- [ ] 定期更新WireGuard软件版本
- [ ] 配置适当的网络流量监控

---

**WireGuard + 容器化部署方案完美兼容现有架构，无需对Dockerfile或podman-compose进行破坏性修改，仅需增强配置以适应VPN网络特性。** 