# 🔧 内部gRPC通信技术实现指南

本文档专注于Web内部gRPC与Backend通信的具体技术实现，架构概述请参考 [GRPC_WEB_INTEGRATION_SUMMARY.md](../GRPC_WEB_INTEGRATION_SUMMARY.md)。

## 📁 V7 Web目录结构集成

遵循 [v7webrules.mdc](./v7webrules.mdc) 的目录结构规范，内部gRPC集成采用以下结构：

```
web/
├── shared/                    # 基础设施层
│   └── api/                  
│       ├── grpc-client.ts    # 统一gRPC客户端（已存在，Web内部使用）
│       └── generated/        # 生成的gRPC代码（内部通信）
│           ├── mvp_crud_pb.js
│           ├── mvp_crud_grpc_web_pb.js
│           └── index.ts      # 统一导出
├── src/                      # Web应用主代码
│   ├── routes/              # HTTP API路由
│   └── middleware/          # 中间件
├── slices/                   # 业务切片
│   └── mvp_crud/
│       └── api.ts           # 内部gRPC → 外部HTTP API适配器
├── proto/                   # Proto文件副本（用于生成）
└── docs/                    # 文档
```

## 🛠️ 环境准备

### 安装依赖
```bash
# 安装Protocol Buffers编译器
sudo apt-get install protobuf-compiler

# 安装gRPC Node.js依赖（服务端gRPC）
cd web
npm install @grpc/grpc-js @grpc/proto-loader

# 安装Web框架依赖
npm install express cors helmet compression
npm install @types/express --save-dev
```

## 🔄 代码生成工具链

### 生成脚本：`scripts/generate-web-client.sh`
```bash
#!/bin/bash
set -e

echo "🚀 生成内部gRPC客户端代码..."

# 确保目录存在
mkdir -p web/proto
mkdir -p web/shared/api/generated

# 复制 Proto 文件到 web 目录
echo "📦 复制 Proto 文件..."
cp backend/proto/*.proto web/proto/

# 生成 Node.js gRPC 客户端代码（用于Web服务端）
echo "🔨 生成 Node.js gRPC 代码..."
cd web/proto

for proto_file in *.proto; do
    echo "处理 $proto_file..."
    # 使用@grpc/proto-loader运行时加载，无需预编译
    # 或者使用grpc_tools.node_protoc预编译（可选）
done

# 生成统一导出文件
echo "📋 生成统一导出文件..."
cat > ../shared/api/generated/index.ts << 'EOF'
// 🤖 自动生成的内部gRPC客户端导出
// 请勿手动修改此文件

import * as grpc from '@grpc/grpc-js';
import * as protoLoader from '@grpc/proto-loader';
import { resolve } from 'path';

// 动态加载Proto定义
const PROTO_PATH = resolve(__dirname, '../../proto/mvp_crud.proto');

const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true
});

export const mvpCrudProto = grpc.loadPackageDefinition(packageDefinition);
EOF

cd ../..
echo "✅ 内部gRPC客户端生成完成！"
```

## 🏗️ 统一客户端架构

扩展现有的 `web/shared/api/grpc-client.ts`，用于Web内部与Backend的gRPC通信：

```typescript
// web/shared/api/grpc-client.ts 扩展实现
import * as grpc from '@grpc/grpc-js';
import * as protoLoader from '@grpc/proto-loader';
import { resolve } from 'path';

// 基础gRPC客户端配置
export class V7GrpcClient {
  protected readonly backendAddress: string;
  protected readonly defaultTimeout: number;
  private client: any;

  constructor(backendAddress: string = 'backend:50051', timeout: number = 10000) {
    this.backendAddress = backendAddress;
    this.defaultTimeout = timeout;
    this.initializeClient();
  }

  private initializeClient() {
    const PROTO_PATH = resolve(__dirname, '../proto/mvp_crud.proto');
    
    const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
      keepCase: true,
      longs: String,
      enums: String,
      defaults: true,
      oneofs: true
    });

    const mvpCrudProto = grpc.loadPackageDefinition(packageDefinition) as any;
    
    this.client = new mvpCrudProto.backend.MvpCrudService(
      this.backendAddress,
      grpc.credentials.createInsecure()
    );
  }

  protected createMetadata(customHeaders?: Record<string, string>): grpc.Metadata {
    const metadata = new grpc.Metadata();
    
    // 添加通用metadata
    metadata.set('Content-Type', 'application/grpc');
    
    // 添加自定义metadata
    if (customHeaders) {
      Object.entries(customHeaders).forEach(([key, value]) => {
        metadata.set(key, value);
      });
    }

    return metadata;
  }

  protected promisifyGrpcCall<T>(
    method: string, 
    request: any
  ): Promise<T> {
    return new Promise((resolve, reject) => {
      this.client[method](request, this.createMetadata(), (error: any, response: T) => {
        if (error) {
          reject(new GrpcError(error.code || 0, error.message || 'Unknown error'));
        } else {
          resolve(response);
        }
      });
    });
  }
}

export class GrpcError extends Error {
  constructor(
    public readonly code: number,
    message: string
  ) {
    super(message);
    this.name = 'GrpcError';
  }
}
```

## 🎯 Slice API适配器（内部gRPC → 外部HTTP）

每个slice实现API网关层，将内部gRPC调用包装为外部HTTP API：

```typescript
// web/slices/mvp_crud/api.ts
import { V7GrpcClient } from '../../shared/api/grpc-client';

export class MvpCrudApiService extends V7GrpcClient {
  constructor() {
    super(); // 连接到backend:50051
  }

  // HTTP API方法：POST /api/items
  async createItem(httpRequest: any): Promise<any> {
    try {
      // 1. HTTP请求 → Proto类型转换
      const grpcRequest = {
        name: httpRequest.name,
        description: httpRequest.description || '',
        value: httpRequest.value || 0
      };

      // 2. 内部gRPC调用
      const grpcResponse = await this.promisifyGrpcCall('createItem', grpcRequest);

      // 3. Proto响应 → HTTP响应转换
      return {
        success: true,
        data: {
          id: grpcResponse.id,
          name: grpcResponse.name,
          description: grpcResponse.description,
          value: grpcResponse.value,
          createdAt: grpcResponse.created_at
        }
      };
    } catch (error) {
      throw this.convertGrpcError(error);
    }
  }

  // HTTP API方法：GET /api/items/:id
  async getItem(id: string): Promise<any> {
    const grpcRequest = { id };
    const grpcResponse = await this.promisifyGrpcCall('getItem', grpcRequest);
    
    return {
      success: true,
      data: this.convertFromProto(grpcResponse)
    };
  }

  // HTTP API方法：GET /api/items
  async listItems(query: any): Promise<any> {
    const grpcRequest = {
      limit: parseInt(query.limit) || 10,
      offset: parseInt(query.offset) || 0,
      sort_by: query.sort_by || 'created_at',
      order: query.order || 'desc'
    };

    const grpcResponse = await this.promisifyGrpcCall('listItems', grpcRequest);
    
    return {
      success: true,
      data: grpcResponse.items.map(item => this.convertFromProto(item)),
      pagination: {
        total: grpcResponse.total,
        limit: grpcRequest.limit,
        offset: grpcRequest.offset
      }
    };
  }

  private convertFromProto(protoItem: any): any {
    return {
      id: protoItem.id,
      name: protoItem.name,
      description: protoItem.description,
      value: protoItem.value,
      createdAt: protoItem.created_at,
      updatedAt: protoItem.updated_at
    };
  }

  private convertGrpcError(grpcError: any): Error {
    // gRPC错误码映射到HTTP状态码
    const errorMap: Record<number, { status: number, message: string }> = {
      5: { status: 404, message: 'Not Found' },    // NOT_FOUND
      6: { status: 409, message: 'Already Exists' }, // ALREADY_EXISTS
      3: { status: 400, message: 'Invalid Argument' }, // INVALID_ARGUMENT
      16: { status: 401, message: 'Unauthenticated' }, // UNAUTHENTICATED
      7: { status: 403, message: 'Permission Denied' }, // PERMISSION_DENIED
    };

    const mapped = errorMap[grpcError.code] || { status: 500, message: 'Internal Server Error' };
    const error = new Error(mapped.message) as any;
    error.status = mapped.status;
    error.originalError = grpcError;
    
    return error;
  }
}
```

## 🌐 HTTP API路由配置

在Web应用中配置标准的HTTP API路由：

```typescript
// web/src/routes/api.ts
import express from 'express';
import { MvpCrudApiService } from '../slices/mvp_crud/api';

const router = express.Router();
const crudService = new MvpCrudApiService();

// 标准REST API端点
router.post('/items', async (req, res, next) => {
  try {
    const result = await crudService.createItem(req.body);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

router.get('/items/:id', async (req, res, next) => {
  try {
    const result = await crudService.getItem(req.params.id);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

router.get('/items', async (req, res, next) => {
  try {
    const result = await crudService.listItems(req.query);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

router.put('/items/:id', async (req, res, next) => {
  try {
    const result = await crudService.updateItem(req.params.id, req.body);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

router.delete('/items/:id', async (req, res, next) => {
  try {
    const result = await crudService.deleteItem(req.params.id);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

export default router;
```

## 🚀 Web应用主入口

```typescript
// web/src/app.ts
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import apiRoutes from './routes/api';

const app = express();

// 中间件
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 静态文件服务
app.use(express.static('dist'));

// API路由
app.use('/api', apiRoutes);

// 健康检查
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// SPA路由支持
app.get('*', (req, res) => {
  res.sendFile(resolve(__dirname, '../dist/index.html'));
});

export default app;
```

## 🔧 开发工作流程

### 1. Backend Proto更新
```bash
cd backend
# 修改proto文件
vim proto/mvp_crud.proto

# 重新编译backend
cargo build
```

### 2. 同步到Web端
```bash
cd ..  # 项目根目录
./scripts/generate-web-client.sh
```

### 3. 更新Slice API
```typescript
// 在web/slices/mvp_crud/api.ts中添加新方法
async newMethod(request: any): Promise<any> {
  const grpcRequest = this.convertToProto(request);
  const grpcResponse = await this.promisifyGrpcCall('newMethod', grpcRequest);
  return this.convertFromProto(grpcResponse);
}
```

### 4. 添加HTTP路由
```typescript
// 在web/src/routes/api.ts中添加路由
router.post('/new-endpoint', async (req, res, next) => {
  try {
    const result = await crudService.newMethod(req.body);
    res.json(result);
  } catch (error) {
    next(error);
  }
});
```

## 📊 性能优化建议

### 1. gRPC连接池
```typescript
class GrpcConnectionPool {
  private clients: Map<string, any> = new Map();
  
  getClient(service: string): any {
    if (!this.clients.has(service)) {
      this.clients.set(service, this.createClient(service));
    }
    return this.clients.get(service);
  }
}
```

### 2. 请求/响应缓存
```typescript
import Redis from 'ioredis';

class CachedGrpcClient extends V7GrpcClient {
  private redis = new Redis(process.env.REDIS_URL);
  
  async cachedCall<T>(cacheKey: string, grpcCall: () => Promise<T>): Promise<T> {
    const cached = await this.redis.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }
    
    const result = await grpcCall();
    await this.redis.setex(cacheKey, 300, JSON.stringify(result)); // 5分钟缓存
    return result;
  }
}
```

### 3. 批量操作
```typescript
async batchCreateItems(items: any[]): Promise<any> {
  const grpcRequest = { items };
  const grpcResponse = await this.promisifyGrpcCall('batchCreateItems', grpcRequest);
  
  return {
    success: true,
    data: grpcResponse.results.map(item => this.convertFromProto(item))
  };
}
```

## 🧪 测试策略

### 1. 单元测试（Mock gRPC）
```typescript
import { jest } from '@jest/globals';
import { MvpCrudApiService } from '../api';

describe('MvpCrudApiService', () => {
  let service: MvpCrudApiService;
  
  beforeEach(() => {
    service = new MvpCrudApiService();
    // Mock gRPC客户端
    service['client'] = {
      createItem: jest.fn()
    };
  });

  it('should create item', async () => {
    const mockResponse = { id: '123', name: 'Test' };
    service['client'].createItem.mockImplementation((req, meta, callback) => {
      callback(null, mockResponse);
    });

    const result = await service.createItem({ name: 'Test' });
    expect(result.success).toBe(true);
    expect(result.data.id).toBe('123');
  });
});
```

### 2. 集成测试（真实gRPC）
```typescript
describe('MvpCrud Integration', () => {
  let service: MvpCrudApiService;

  beforeAll(async () => {
    // 启动测试Backend服务
    service = new MvpCrudApiService();
  });

  it('should perform full CRUD cycle', async () => {
    // 创建
    const created = await service.createItem({ name: 'Integration Test' });
    expect(created.success).toBe(true);
    
    // 读取
    const fetched = await service.getItem(created.data.id);
    expect(fetched.data.name).toBe('Integration Test');
    
    // 删除
    const deleted = await service.deleteItem(created.data.id);
    expect(deleted.success).toBe(true);
  });
});
```

## 🎯 最佳实践总结

1. **架构清晰**：Web作为API网关，内部使用gRPC，外部提供HTTP
2. **类型安全**：Proto定义确保内部通信类型安全
3. **错误处理**：统一的gRPC错误映射到HTTP状态码
4. **性能优化**：连接池、缓存、批量操作
5. **测试完整**：单元测试Mock，集成测试真实通信
6. **部署简单**：标准Web应用，无需特殊代理

这种架构既保留了gRPC的性能优势，又提供了标准的HTTP API接口，是实际生产环境的最佳选择。 