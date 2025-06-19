# FMOD v7 运行时API文档

> 🎯 此文档基于运行时收集的真实API调用数据生成，100%准确

## 📅 生成信息

- **生成时间**: 2025-06-18 08:21:43 UTC
- **数据来源**: 运行时API调用收集
- **准确度**: 100% (基于真实调用)
- **版本**: v2.0 (生产就绪)

## 🚀 快速开始

### 安装和导入

```typescript
// 导入API客户端
import { apiClient, auth, items, system } from './api/client-runtime';

// 或者导入特定类型
import type { LoginRequest, Item, CreateItemRequest } from './types/api-runtime';
```

### 基础使用

```typescript
// 1. 用户认证
const loginResponse = await auth.login({
  username: 'your-username',
  password: 'your-password'
});

// 2. 获取Items列表
const itemsList = await items.list({
  page: 1,
  page_size: 10
});

// 3. 创建新Item
const newItem = await items.create({
  name: 'My New Item',
  description: 'Item description'
});

// 4. 健康检查
const health = await system.health();
```

## 🔧 API客户端功能

### 🔐 认证管理

```typescript
// 登录（会自动设置token）
await auth.login({ username: 'user', password: 'pass' });

// 验证当前token
await auth.validate();

// 登出（会自动清除token）
await auth.logout();

// 手动设置token
auth.setToken('your-jwt-token');

// 移除token
auth.removeToken();
```

### 📝 Items CRUD操作

```typescript
// 获取Items列表（支持分页和搜索）
const items = await items.list({
  page: 1,
  page_size: 20,
  search: 'keyword',
  sort_by: 'created_at',
  sort_order: 'desc'
});

// 获取单个Item
const item = await items.get('item-id');

// 创建Item
const newItem = await items.create({
  name: 'Item Name',
  description: 'Optional description',
  value: 100
});

// 更新Item
const updatedItem = await items.update('item-id', {
  name: 'New Name'
});

// 删除Item
await items.delete('item-id');
```

### 🏥 系统监控

```typescript
// 健康检查
const health = await system.health();

// API信息
const info = await system.info();

// 运行时统计
const stats = await system.stats();
```

## ⚡ 高级功能

### 错误处理

```typescript
import { isApiError } from './api/client-runtime';

try {
  const items = await items.list();
} catch (error) {
  if (isApiError(error)) {
    console.log(`API错误: ${error.code} - ${error.message}`);
    console.log(`状态码: ${error.status}`);
    console.log(`追踪ID: ${error.traceId}`);
  } else {
    console.log('其他错误:', error);
  }
}
```

### 自定义配置

```typescript
import { ApiClient } from './api/client-runtime';

const customClient = new ApiClient({
  baseUrl: 'https://api.yourapp.com',
  timeout: 10000,
  retries: 5,
  retryDelay: 2000,
  headers: {
    'X-Custom-Header': 'value'
  }
});
```

### 类型安全

```typescript
import type { Item, CreateItemRequest } from './types/api-runtime';

// 完全类型安全的函数
function processItem(item: Item): string {
  return `${item.name} (${item.id})`;
}

function createItemData(): CreateItemRequest {
  return {
    name: 'Required field',
    description: 'Optional field',
    // TypeScript会检查所有字段类型
  };
}
```

## 📊 可用API端点

### 🔐 认证端点

- `POST /api/auth/login` - 用户登录
- `GET /api/auth/validate` - 验证token
- `POST /api/auth/logout` - 用户登出

### 📝 Items端点

- `GET /api/items` - 获取Items列表
- `GET /api/items/{id}` - 获取单个Item
- `POST /api/items` - 创建Item
- `PUT /api/items/{id}` - 更新Item
- `DELETE /api/items/{id}` - 删除Item

### 🏥 系统端点

- `GET /health` - 健康检查
- `GET /api/info` - API信息
- `GET /api/runtime/data` - 运行时统计

### 👤 用户端点

- `GET /user/events` - 获取用户事件

## 🛡️ 客户端特性

- ✅ **完全类型安全** - 基于真实API生成的TypeScript类型
- ✅ **自动重试** - 智能重试失败的请求
- ✅ **超时控制** - 可配置的请求超时
- ✅ **错误处理** - 结构化的错误信息
- ✅ **认证管理** - 自动token管理
- ✅ **请求取消** - 支持请求取消
- ✅ **查询参数** - 自动处理URL查询参数
- ✅ **内容类型检测** - 智能处理JSON和文本响应

## 🔄 更新流程

要更新API客户端代码：

1. 确保服务器运行在开发模式
2. 运行导出脚本：`./scripts/runtime_api_export.sh`
3. 新的类型和客户端代码会自动生成

## 📝 注意事项

- 此代码是自动生成的，请勿手动修改
- 类型定义基于真实的API响应结构
- 客户端包含智能重试和错误处理逻辑
- 支持认证token的自动管理
- 所有API调用都是类型安全的

---

*📅 最后更新: 2025-06-18 08:21:43 UTC*
