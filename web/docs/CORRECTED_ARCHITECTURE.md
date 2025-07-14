# 🏗️ V7项目修正架构文档

## 🚨 重要澄清：开发 vs 生产架构

### ❌ 之前的错误理解
```
Browser → Vite Dev Server → HTTP Proxy → Backend HTTP API  ❌ 
```
**问题**：Backend只有`/health` HTTP端点，其他都是gRPC，此流程无法工作。

### ✅ 正确的架构设计

#### 🛠️ 开发环境 (`npm run dev`)
```
Browser → SolidJS Dev (Vite) → Connect-Web Client → Backend gRPC:50051
```

**技术栈**：
- **前端**：SolidJS + Vite 开发服务器 (localhost:5173)
- **通信**：`@connectrpc/connect-web` 直接调用gRPC
- **后端**：Backend gRPC服务 (localhost:50051)

**特点**：
- ✅ 无需中间代理，直接gRPC-Web通信
- ✅ 热重载、快速开发
- ✅ TypeScript类型安全
- ❌ 需要后端支持CORS和gRPC-Web协议

#### 🚀 生产环境 (容器化)
```
Browser → nginx:3000 → Static Files (SolidJS构建产物)
Browser → nginx:3000/api → Connect代理:8080 → Backend gRPC:50051
```

**容器架构**：
- **Web容器**：`nginx` + SolidJS静态文件
- **Backend容器**：Rust gRPC服务
- **通信**：nginx代理到Connect代理进行协议转换

## 📁 目录结构 - 清理后

### 🗂️ Web项目结构
```
web/
├── config/
│   ├── nginx.prod.conf      # 生产nginx配置
│   ├── dev-proxy.ts         # 开发环境配置（已移出src/）
│   └── vite.ts             # Vite配置
├── shared/                  # 共享基础设施
│   ├── api/
│   │   ├── connect-client.ts  # ✅ gRPC-Web客户端
│   │   ├── base.ts           # HTTP基础客户端
│   │   └── types.ts          # API类型定义
│   └── ...
├── slices/mvp_crud/         # MVP CRUD切片
│   ├── api.ts              # HTTP API客户端
│   ├── hooks.ts            # React/Solid钩子
│   ├── types.ts            # 类型定义
│   └── view.tsx            # UI组件
├── src/                    # 瀑布流框架（不放置业务逻辑）
│   └── shared/
├── Dockerfile              # ✅ 生产容器（单文件架构）
└── package.json
```

### 🗑️ 已删除的文件
```
❌ web/shared/bridge/         # Go代码不应在前端项目
❌ web/shared/api/grpc-client.ts  # Node.js gRPC（浏览器不支持）
❌ web/shared/api/generated/  # 依赖已删除的grpc-client
❌ web/deploy/               # 混乱的部署目录
❌ web/src/dev-proxy.ts      # 已移动到config/
```

## 🔄 开发工作流程

### 1. 🛠️ 本地开发
```bash
# 启动Backend
cd backend && cargo run

# 启动前端开发服务器
cd web && npm run dev
```

**架构**：SolidJS直接通过Connect-Web调用Backend gRPC

### 2. 🧪 本地容器验证
```bash
# 构建Web容器
cd web && podman build -t v7-web .

# 运行容器网络
podman network create v7-network
podman run -d --name=backend --network=v7-network v7-backend
podman run -d --name=web --network=v7-network -p 3000:3000 v7-web
```

### 3. 🚀 推送部署
```bash
git push origin main
# → GitHub Actions自动构建和部署
```

## 🎯 API客户端架构

### 开发环境：Connect-Web直连
```typescript
// web/shared/api/connect-client.ts
import { createClient } from '@connectrpc/connect-web';

const client = createClient(MvpCrudService, {
  baseUrl: "http://localhost:50051"  // 直接连Backend gRPC
});
```

### 生产环境：HTTP API 
```typescript
// web/slices/mvp_crud/api.ts  
class MvpCrudApiService {
  async createItem(request) {
    return this.request('/api/mvp-crud/items', {
      method: 'POST',
      body: JSON.stringify(request)
    });
  }
}
```

## 🚧 待解决问题

1. **Backend gRPC-Web支持**：需要在Backend添加gRPC-Web协议支持
2. **CORS配置**：开发环境需要Backend支持跨域
3. **Connect代理**：生产环境需要独立的Connect代理服务
4. **TypeScript错误**：hooks.ts中的API响应处理错误

## 📋 下一步行动

1. ✅ 清理目录结构（已完成）
2. ⏳ 修复TypeScript错误
3. ⏳ 配置Backend的gRPC-Web支持
4. ⏳ 实现Connect代理服务
5. ⏳ 测试完整的开发→生产流程 