# 🔍 gRPC-Web连接问题深度分析报告

## 📊 问题总结

基于您提供的详细日志，我发现了两个主要问题：

### 🔴 问题1：Vite代理配置错误导致HTTP 400
**现象**：
```
POST http://192.168.31.84:5173/v7.backend.BackendService/HealthCheck net::ERR_ABORTED 400 (Bad Request)
```

**根本原因**：
1. **错误的baseUrl配置**：gRPC客户端配置为 `http://192.168.31.84:5173`（前端端口）
2. **代理路径不匹配**：Vite代理配置为 `^/v7\\.backend\\.BackendService/.*`，但请求被发送到5173端口
3. **backend服务未运行**：测试时backend进程不在运行状态

### 🔴 问题2：CORS问题（test-grpc-protobuf.html）
**现象**：
```
Access to fetch at 'http://192.168.31.84:50053/v7.backend.BackendService/HealthCheck' from origin 'http://192.168.31.84:5173' has been blocked by CORS policy: Request header field connect-protocol-version is not allowed by Access-Control-Allow-Headers in preflight response.
```

**根本原因**：
- ConnectRPC添加了自定义头部 `connect-protocol-version`
- Backend的CORS配置没有允许这个头部

## 🔧 解决方案

### 解决方案1：修复gRPC客户端配置

#### 当前错误配置：
```typescript
// grpc-client.ts 第55行
const defaultBaseUrl = isDev 
  ? window.location.origin  // ❌ 错误：指向5173端口
  : 'http://192.168.31.84:50053';
```

#### 正确配置：
```typescript
// 开发环境应该直接指向backend端口，或使用代理
const defaultBaseUrl = isDev 
  ? 'http://192.168.31.84:50053'  // ✅ 直连backend
  : 'http://192.168.31.84:50053';
```

### 解决方案2：修复Vite代理配置

#### 修复代理路径匹配：
```typescript
// vite.config.ts
server: {
  proxy: {
    // 修复：匹配所有gRPC-Web请求
    '/v7.backend.BackendService': {
      target: 'http://192.168.31.84:50053',
      changeOrigin: true,
      secure: false,
      rewrite: (path) => path, // 保持原路径
      configure: (proxy, _options) => {
        proxy.on('proxyReq', (proxyReq, req, _res) => {
          console.log('🚀 Proxying gRPC-Web request:', req.method, req.url);
          // 确保gRPC-Web头部正确传递
          if (req.headers['content-type']?.includes('application/grpc-web')) {
            proxyReq.setHeader('content-type', req.headers['content-type']);
          }
          if (req.headers['x-grpc-web']) {
            proxyReq.setHeader('x-grpc-web', req.headers['x-grpc-web']);
          }
        });
      },
    }
  }
}
```

### 解决方案3：Backend CORS配置增强

需要在backend中添加对ConnectRPC头部的支持：

```rust
// backend/src/main.rs
let cors = CorsLayer::new()
    .allow_origin(Any)
    .allow_methods([Method::GET, Method::POST, Method::OPTIONS])
    .allow_headers([
        AUTHORIZATION,
        ACCEPT,
        CONTENT_TYPE,
        HeaderName::from_static("x-grpc-web"),
        HeaderName::from_static("grpc-timeout"),
        HeaderName::from_static("grpc-encoding"),
        HeaderName::from_static("connect-protocol-version"), // ✅ 添加ConnectRPC头部
        HeaderName::from_static("connect-timeout-ms"),
    ])
    .expose_headers([
        HeaderName::from_static("grpc-status"),
        HeaderName::from_static("grpc-message"),
        HeaderName::from_static("grpc-status-details-bin"),
    ]);
```

## 🎯 推荐的架构选择

基于分析，我推荐以下架构：

### 选择A：直连模式（推荐）
```
Browser → ConnectRPC Client → Backend gRPC-Web (50053)
```

**优势**：
- 简单直接，无需代理层
- 性能最优
- 调试容易

**实现**：
```typescript
const grpcClient = new UnifiedGrpcClient({
  baseUrl: 'http://192.168.31.84:50053',  // 直连backend
  enableLogging: true
});
```

### 选择B：Vite代理模式
```
Browser → Vite Dev Server (5173) → Proxy → Backend gRPC-Web (50053)
```

**优势**：
- 避免CORS问题
- 开发环境统一端口

**实现**：
```typescript
const grpcClient = new UnifiedGrpcClient({
  baseUrl: window.location.origin,  // 使用代理
  enableLogging: true
});
```

## 🚀 立即修复步骤

1. **启动backend服务**：
   ```bash
   cd backend && cargo run
   ```

2. **修复gRPC客户端配置**：
   - 选择直连模式或代理模式
   - 更新baseUrl配置

3. **测试连接**：
   ```bash
   # 直接测试backend
   curl -v -X POST -H "Content-Type: application/grpc-web+proto" \
        http://192.168.31.84:50053/v7.backend.BackendService/HealthCheck
   ```

4. **验证Web客户端**：
   - 打开浏览器开发者工具
   - 访问测试页面
   - 检查网络请求是否正确

## 📋 检查清单

- [ ] Backend服务正在运行（端口50053）
- [ ] gRPC客户端baseUrl配置正确
- [ ] Vite代理配置（如果使用代理模式）
- [ ] Backend CORS配置包含ConnectRPC头部
- [ ] 浏览器网络请求到达正确端点
- [ ] 请求使用正确的protobuf格式

通过这些修复，您的gRPC-Web通信应该能够正常工作！ 