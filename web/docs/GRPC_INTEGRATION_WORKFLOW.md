# 🔄 gRPC-Web 集成工作流程指南

## 📋 概述

本文档描述了V7架构中前后端gRPC集成的标准工作流程，确保类型安全和代码一致性。

## 🏗️ 架构概览

```
Backend (Rust + gRPC)
    ↓ proto定义
Generated Proto Types (TypeScript)
    ↓ 类型安全
Frontend Slices (SolidJS + TypeScript)
```

## 🔧 完整工作流程

### 1. 后端开发阶段

#### 1.1 定义Proto文件
```protobuf
// backend/proto/backend.proto
service BackendService {
  rpc CreateItem(CreateItemRequest) returns (CreateItemResponse);
  rpc ListItems(ListItemsRequest) returns (ListItemsResponse);
  // ... 其他方法
}

message CreateItemRequest {
  string name = 1;
  optional string description = 2;
  int32 value = 3;
}
```

#### 1.2 实现后端服务
```rust
// backend/src/slices/mvp_crud/functions.rs
pub async fn create_item<S>(
    service: S,
    req: CreateItemRequest
) -> Result<CreateItemResponse>
where S: CrudService {}
```

#### 1.3 启动后端服务
```bash
cd backend
cargo run
# 🚀 v7架构主gRPC服务器启动在 grpc://0.0.0.0:50053
```

### 2. 生成前端集成代码

#### 2.1 运行代码生成脚本
```bash
cd /path/to/v7
./scripts/generate-web-client.sh
```

#### 2.2 生成的文件结构
```
web/shared/api/generated/
├── backend_pb.ts          # Proto消息类型 + 编码/解码函数
├── backend_connect.ts     # Connect服务定义
├── index.ts              # 统一导出
└── README.md             # 使用说明
```

#### 2.3 生成的关键内容
```typescript
// backend_pb.ts
export interface CreateItemRequest {
  name?: string;
  description?: string;
  value?: number;
}

export function encodeCreateItemRequest(message: CreateItemRequest): Uint8Array;
export function decodeCreateItemResponse(binary: Uint8Array): CreateItemResponse;

// backend_connect.ts
export const BackendService = {
  typeName: "v7.backend.BackendService",
  methods: {
    createItem: { name: "CreateItem", kind: "unary" as const },
    // ...
  },
};
```

### 3. 前端切片开发

#### 3.1 继承V7ConnectClient基类
```typescript
// web/slices/mvp_crud/api.ts
import { 
  V7ConnectClient,
  type GrpcCreateItemRequest,
  type GrpcCreateItemResponse,
  encodeCreateItemRequest,
  decodeCreateItemResponse,
} from '../../shared/api/connect-client';

export class MvpCrudApiService extends V7ConnectClient {
  constructor() {
    super('http://192.168.31.84:50053');
  }

  async create(request: CreateItemRequest): Promise<ApiResponse<Item>> {
    const grpcRequest = convertToGrpcRequest(request);
    
    const grpcResponse = await this.callBackendMethod<GrpcCreateItemRequest, GrpcCreateItemResponse>(
      'CreateItem',
      grpcRequest,
      encodeCreateItemRequest,
      decodeCreateItemResponse
    );

    return convertToFrontendResponse(grpcResponse);
  }
}
```

#### 3.2 类型转换层
```typescript
// 前端类型 -> gRPC类型
function convertToGrpcRequest(request: CreateItemRequest): GrpcCreateItemRequest {
  return {
    name: request.name,
    description: request.description,
    value: request.value || 0,
  };
}

// gRPC类型 -> 前端类型
function convertGrpcItemToFrontendItem(grpcItem: GrpcItem): Item {
  return {
    id: grpcItem.id || '',
    name: grpcItem.name || '',
    description: grpcItem.description || '',
    value: grpcItem.value || 0,
    createdAt: grpcItem.created_at || '',
    updatedAt: grpcItem.updated_at || '',
  };
}
```

#### 3.3 在Hooks中使用API
```typescript
// web/slices/mvp_crud/hooks.ts
import { mvpCrudApi } from './api';

export function useCrud() {
  const createItem = async (data: CreateItemRequest) => {
    const response = await mvpCrudApi.create(data);
    if (response.success) {
      // 处理成功响应
      return response.data;
    } else {
      // 处理错误
      throw new Error(response.error);
    }
  };

  return { createItem };
}
```

## 🔄 开发迭代流程

### 当Backend Proto发生变化时

1. **更新Backend Proto文件**
   ```bash
   # 修改 backend/proto/backend.proto
   ```

2. **重新构建Backend**
   ```bash
   cd backend
   cargo build
   ```

3. **重新生成前端类型**
   ```bash
   ./scripts/generate-web-client.sh
   ```

4. **更新前端代码**
   - 检查类型错误
   - 更新类型转换函数
   - 测试API调用

## 📊 集成信息的价值

### ✅ 生成的集成信息提供：

1. **类型安全**：编译时类型检查，避免运行时错误
2. **自动序列化**：正确的protobuf编码/解码
3. **服务定义**：标准化的gRPC服务调用方式
4. **版本同步**：确保前后端接口一致性

### 🎯 正确的使用方式：

```typescript
// ✅ 正确：使用生成的类型和函数
import { 
  type GrpcCreateItemRequest,
  encodeCreateItemRequest,
  decodeCreateItemResponse 
} from '../../shared/api/connect-client';

// ❌ 错误：手动实现序列化
const request = JSON.stringify(data); // 这不是protobuf格式
```

## 🚨 常见问题和解决方案

### 问题1：V7ConnectClient导出错误
```typescript
// 错误信息：The requested module does not provide an export named 'V7ConnectClient'

// 解决方案：确保connect-client.ts正确导出
export class V7ConnectClient { /* ... */ }
```

### 问题2：生成的类型未被使用
```typescript
// 问题：切片直接定义自己的类型，没有使用生成的类型

// 解决方案：使用类型转换层
function convertToGrpcRequest(frontendRequest: CreateItemRequest): GrpcCreateItemRequest {
  // 转换逻辑
}
```

### 问题3：protobuf序列化错误
```typescript
// 问题：使用JSON.stringify代替protobuf编码

// 解决方案：使用生成的编码函数
const encoded = encodeCreateItemRequest(grpcRequest);
```

## 🎯 最佳实践

### 1. 保持类型分离
- Frontend Types：用户界面友好的类型
- gRPC Types：与后端Proto严格对应的类型
- 通过转换函数连接两者

### 2. 统一错误处理
```typescript
try {
  const response = await this.callBackendMethod(/* ... */);
  return convertToFrontendResponse(response);
} catch (error) {
  if (error instanceof ConnectError) {
    // 处理gRPC错误
  }
  // 处理其他错误
}
```

### 3. 性能优化
- 使用连接池和重试机制
- 实现适当的缓存策略
- 监控gRPC调用性能

## 🔧 工具链支持

### 开发时
- TypeScript编译器检查类型一致性
- ESLint检查代码质量
- 开发服务器热重载

### 部署时
- 自动化测试验证API集成
- 版本兼容性检查
- 性能监控

---

通过遵循这个工作流程，确保前后端gRPC集成的类型安全、性能优化和可维护性。 