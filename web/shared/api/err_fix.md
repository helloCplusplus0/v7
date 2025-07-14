# gRPC-Web 错误修复指南

这份文档总结了我们在实现 gRPC-Web 通信过程中遇到的所有问题和解决方案，旨在帮助未来的开发避免相同的错误。

## 🔴 核心问题：协议不兼容

### 问题描述
最初使用 ConnectRPC 协议与 Rust tonic-web 后端通信时出现 400 Bad Request 错误。

### 根本原因
- **ConnectRPC 协议**: 使用 `application/proto` Content-Type + Connect 协议规范
- **tonic-web 期望**: 使用 `application/grpc-web+proto` Content-Type + 标准 gRPC-Web 协议

### 解决方案
完全重写 gRPC 客户端，移除 ConnectRPC 依赖，实现标准 gRPC-Web 协议：

```typescript
// 正确的 headers
headers: {
  'Content-Type': 'application/grpc-web+proto',
  'X-Grpc-Web': '1'
}

// 正确的消息格式编码
const serializedRequest = request.toBinary();
const encodedRequest = this.encodeGrpcWebRequest(serializedRequest);

// 正确的响应解码
const decodedResponse = this.decodeGrpcWebResponse(responseData);
const response = ResponseType.fromBinary(decodedResponse);
```

## 🔧 gRPC-Web 客户端实现细节

### 1. 消息编码格式
gRPC-Web 使用特定的二进制格式：

```typescript
// 编码格式: [压缩标志(1字节)] + [长度(4字节)] + [数据]
private encodeGrpcWebRequest(data: Uint8Array): Uint8Array {
  const result = new Uint8Array(5 + data.length);
  result[0] = 0; // 未压缩
  
  // 写入长度 (big-endian)
  const length = data.length;
  result[1] = (length >>> 24) & 0xff;
  result[2] = (length >>> 16) & 0xff;
  result[3] = (length >>> 8) & 0xff;
  result[4] = length & 0xff;
  
  // 写入数据
  result.set(data, 5);
  return result;
}
```

### 2. 响应解码
```typescript
private decodeGrpcWebResponse(data: Uint8Array): Uint8Array {
  if (data.length < 5) {
    throw new GrpcError('Invalid gRPC-Web response: too short');
  }
  
  const compressed = data[0] === 1;
  if (compressed) {
    throw new GrpcError('Compressed responses not supported');
  }
  
  // 读取长度 (big-endian)
  const length = (data[1] << 24) | (data[2] << 16) | (data[3] << 8) | data[4];
  
  if (data.length < 5 + length) {
    throw new GrpcError('Invalid gRPC-Web response: length mismatch');
  }
  
  return data.slice(5, 5 + length);
}
```

### 3. Protobuf 序列化/反序列化
```typescript
// 序列化请求
const serializedRequest = (request as any).toBinary();

// 反序列化响应
private deserializeResponse<T>(methodName: string, data: Uint8Array): T {
  switch (methodName) {
    case 'ListItems':
      return ListItemsResponse.fromBinary(data) as T;
    case 'CreateItem':
      return CreateItemResponse.fromBinary(data) as T;
    // ... 其他方法
    default:
      throw new GrpcError(`Unknown method: ${methodName}`);
  }
}
```

## 🌐 CORS 配置问题

### 问题描述
初始的 CORS 配置不完整，缺少 gRPC-Web 和 ConnectRPC 所需的特定 headers。

### 解决方案
后端 CORS 配置需要包含所有必要的 headers：

```rust
.allow_headers(vec![
    // 标准 HTTP headers
    axum::http::header::HeaderName::from_static("content-type"),
    axum::http::header::HeaderName::from_static("authorization"),
    
    // ConnectRPC 所需 headers
    axum::http::header::HeaderName::from_static("connect-protocol-version"),
    axum::http::header::HeaderName::from_static("connect-timeout-ms"),
    
    // gRPC-Web 所需 headers
    axum::http::header::HeaderName::from_static("x-grpc-web"),
    axum::http::header::HeaderName::from_static("grpc-timeout"),
    
    // 其他必要 headers
    axum::http::header::HeaderName::from_static("accept"),
    axum::http::header::HeaderName::from_static("accept-encoding"),
    axum::http::header::HeaderName::from_static("user-agent"),
])
.expose_headers(vec![
    "grpc-status",
    "grpc-message",
    "grpc-status-details-bin",
    "connect-protocol-version",
    "content-length",
    "date",
])
```

## 🔄 重复请求问题

### 问题描述
前端发送了多个重复的 gRPC 请求，导致性能问题。

### 根本原因
多个 `createEffect` 同时触发：
- `onMount` 调用 `loadItems()`
- `debouncedSearch` 变化触发搜索 effect
- `pageSize` 从 localStorage 加载触发分页 effect
- `currentPage` 初始化触发分页 effect

### 解决方案
重构 hooks 以避免重复请求：

```typescript
// 引入加载控制机制
const [shouldLoad, setShouldLoad] = createSignal(false);
const [loadTrigger, setLoadTrigger] = createSignal(0);

// 统一的加载 effect
createEffect(() => {
  if (!shouldLoad()) return;
  
  // 监听触发器变化
  loadTrigger();
  
  // 执行加载逻辑
  loadItems();
});

// 在 onMount 中完成初始化后再启用加载
onMount(() => {
  // 完成所有初始化
  batch(() => {
    setPageSize(preferences().pageSize);
    setSortField(preferences().sortField);
    setSortOrder(preferences().sortOrder);
  });
  
  // 启用加载
  setShouldLoad(true);
});
```

## 🔧 开发环境配置

### Vite 代理配置
```typescript
// vite.config.ts
server: {
  proxy: {
    '/v7.backend.BackendService': {
      target: 'http://192.168.31.84:50053',
      changeOrigin: true,
      secure: false,
      ws: false,
      timeout: 30000,
      configure: (proxy, _options) => {
        proxy.on('proxyReq', (proxyReq, req, _res) => {
          // 转发所有必要的 headers
          const headersToForward = [
            'content-type',
            'x-grpc-web',
            'grpc-timeout',
            'accept',
            'accept-encoding',
            'user-agent',
            'authorization'
          ];
          
          headersToForward.forEach(header => {
            if (req.headers[header]) {
              proxyReq.setHeader(header, req.headers[header]);
            }
          });
        });
      },
    }
  }
}
```

### 环境自适应配置
```typescript
// 智能环境检测
const isDev = import.meta.env.DEV;
const defaultBaseUrl = isDev 
  ? `${window.location.protocol}//${window.location.host}`  // 开发环境使用 Vite 代理
  : 'http://192.168.31.84:50053';  // 生产环境直连
```

## 🛠️ 权威技术参考

### gRPC-Web 协议规范
- **消息格式**: 使用 5 字节前缀（压缩标志 + 长度）+ protobuf 数据
- **Content-Type**: 必须使用 `application/grpc-web+proto`
- **Headers**: 必须包含 `X-Grpc-Web: 1`

### Rust tonic-web 最佳实践
- **CORS 配置**: 必须正确配置所有必要的 headers
- **压缩支持**: 可选择性启用 gzip 压缩
- **错误处理**: 使用 gRPC status codes 而非 HTTP status codes

### 前端实现要点
- **二进制数据处理**: 使用 Uint8Array 处理二进制数据
- **错误处理**: 区分网络错误、协议错误和业务错误
- **性能优化**: 实现请求缓存和重试机制

## 🚨 常见错误和解决方案

### 1. 400 Bad Request
**原因**: 协议不匹配或请求格式错误
**解决**: 确保使用正确的 Content-Type 和消息格式

### 2. CORS 错误
**原因**: 缺少必要的 CORS headers
**解决**: 完善后端 CORS 配置

### 3. 重复请求
**原因**: 多个 effect 同时触发
**解决**: 使用触发器模式统一管理加载状态

### 4. 序列化错误
**原因**: 使用错误的 protobuf API
**解决**: 使用 `toBinary()` 和 `fromBinary()` 方法

## 📋 开发检查清单

### 后端检查
- [ ] CORS 配置包含所有必要 headers
- [ ] 支持 gRPC-Web 协议
- [ ] 正确处理 OPTIONS 预检请求
- [ ] 错误响应格式正确

### 前端检查
- [ ] 使用正确的 Content-Type
- [ ] 实现正确的消息编码/解码
- [ ] 处理所有错误情况
- [ ] 避免重复请求
- [ ] 环境配置正确

### 测试验证
- [ ] 使用 curl 测试 gRPC-Web 请求
- [ ] 验证 CORS 预检请求
- [ ] 测试错误处理
- [ ] 性能测试

## 🔮 未来改进建议

1. **性能优化**
   - 实现连接池
   - 添加请求缓存
   - 优化重试策略

2. **错误处理**
   - 更详细的错误分类
   - 用户友好的错误消息
   - 错误监控和报告

3. **开发体验**
   - 自动化测试
   - 开发工具集成
   - 文档完善

## 💡 关键经验教训

1. **协议兼容性至关重要**: 确保前后端使用相同的协议规范
2. **CORS 配置要全面**: 不要遗漏任何必要的 headers
3. **状态管理要谨慎**: 避免多个 effect 同时触发相同操作
4. **错误处理要完善**: 区分不同类型的错误并提供相应处理
5. **测试要充分**: 使用多种工具验证实现的正确性

通过遵循这些指南，可以避免我们在开发过程中遇到的大部分问题，实现稳定可靠的 gRPC-Web 通信。
