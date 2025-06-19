## 📋 Web v7 前端开发范式设计文档

基于后端 v7 架构的轻量化前端开发范式，专为 Vite + SolidJS 技术栈设计。

---

## 🎯 核心设计原则

### v7 前后端对应关系

| 后端 v7 原则 | 前端 v7 对应实现 |
|-------------|-----------------|
| Function-first Design | **Signal-first Components** - 组件围绕信号设计 |
| Static Dispatch + Generics | **TypeScript 静态类型** + 泛型组件优化 |
| Clone Trait Support | **Immutable Signals** + 细粒度响应式更新 |
| Dual-Path Exposure | **独立组件** + 路由集成双重使用模式 |
| Infrastructure Reuse | **Shared Signals** + 工具函数重用 |
| Zero Runtime Overhead | **编译时优化** + SolidJS 零虚拟DOM开销 |

---

## 📁 极简切片架构

### 目录结构（只有4个核心文件）

```typescript
// web/slices/{slice_name}/
web/slices/{slice_name}/
├── types.ts              // 类型定义（手动同步backend类型）
├── api.ts                // API客户端（手动同步backend client）
├── hooks.ts              // 业务逻辑（SolidJS signals/stores）
├── view.tsx              // UI组件（SolidJS组件）
└── index.ts              // 统一导出
```

**设计原理**：最小化文件数量，每个文件职责单一明确。

---

## 🔄 代码同步策略评估

### ❌ 直接引用 Backend 代码的问题

```typescript
// ❌ 违背前后端分离原则
import { ApiClient } from '../../../backend/frontend/src/api/client-runtime';
import type { Item } from '../../../backend/frontend/src/types/api-runtime';
```

**问题**：
- 打破前后端代码边界
- 增加构建复杂度
- 违背分离架构原则
- 部署时需要包含backend代码

### ✅ 手动同步的最佳实践

```typescript
// ✅ 前端独立维护类型和客户端
// types.ts - 手动同步backend类型
export interface Item {
  id: string;
  name: string;
  description?: string;
  value: number;
  created_at: string;
  updated_at: string;
}

// api.ts - 手动同步backend客户端逻辑
export const itemsApi = {
  list: () => fetch('/api/items').then(r => r.json()),
  get: (id: string) => fetch(`/api/items/${id}`).then(r => r.json()),
  create: (data: CreateItemRequest) => 
    fetch('/api/items', { method: 'POST', body: JSON.stringify(data) }),
};
```

**优势**：
- 保持前后端独立性
- 构建简单、部署灵活
- 类型安全且可定制
- 符合微服务架构原则

---

## 🧩 切片实现模板

### 1. types.ts - 类型定义

```typescript
// 与backend api-runtime.ts保持同步
export interface Item {
  id: string;
  name: string;
  description?: string;
  value: number;
  created_at: string;
  updated_at: string;
}

export interface CreateItemRequest {
  name: string;
  description?: string;
  value?: number;
}

export interface ItemsListResponse {
  items: Item[];
  total: number;
  page: number;
  page_size: number;
}
```

### 2. api.ts - API客户端

```typescript
// 轻量化API封装，基于backend client-runtime.ts逻辑
class ItemsApiClient {
  private baseUrl = 'http://localhost:3000';
  
  async list(query?: ListItemsQuery): Promise<ItemsListResponse> {
    const url = new URL('/api/items', this.baseUrl);
    if (query) {
      Object.entries(query).forEach(([k, v]) => 
        v && url.searchParams.set(k, String(v)));
    }
    const response = await fetch(url);
    return response.json();
  }
  
  async create(data: CreateItemRequest): Promise<Item> {
    const response = await fetch(`${this.baseUrl}/api/items`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    return response.json();
  }
}

export const itemsApi = new ItemsApiClient();
```

### 3. hooks.ts - 业务逻辑

```typescript
// SolidJS signals 实现细粒度响应式
import { createSignal, createResource } from 'solid-js';
import { itemsApi } from './api';
import type { Item, CreateItemRequest } from './types';

export function useItems() {
  // 📊 响应式状态
  const [items, setItems] = createSignal<Item[]>([]);
  const [loading, setLoading] = createSignal(false);
  
  // 📡 数据获取
  const [itemsResource] = createResource(async () => {
    setLoading(true);
    try {
      const response = await itemsApi.list();
      setItems(response.items);
      return response;
    } finally {
      setLoading(false);
    }
  });
  
  // 🔄 操作函数
  const createItem = async (data: CreateItemRequest) => {
    const newItem = await itemsApi.create(data);
    setItems(prev => [...prev, newItem]);
    return newItem;
  };
  
  return {
    items,
    loading,
    createItem,
    refetch: itemsResource.refetch,
  };
}
```

### 4. view.tsx - UI组件

```typescript
// SolidJS组件 - 零虚拟DOM开销
import { Component, For, Show } from 'solid-js';
import { useItems } from './hooks';

export const ItemsView: Component = () => {
  const { items, loading, createItem } = useItems();
  
  return (
    <div class="items-container">
      <Show when={loading()} fallback={
        <For each={items()}>
          {(item) => (
            <div class="item-card" key={item.id}>
              <h3>{item.name}</h3>
              <p>{item.description}</p>
              <span>Value: {item.value}</span>
            </div>
          )}
        </For>
      }>
        <div class="loading">Loading...</div>
      </Show>
    </div>
  );
};
```

### 5. index.ts - 统一导出

```typescript
// 切片公共接口
export { ItemsView } from './view';
export { useItems } from './hooks';
export type { Item, CreateItemRequest } from './types';
export { itemsApi } from './api';
```

---

## ⚡ 性能优化策略

### 1. SolidJS 细粒度响应式

```typescript
// ✅ 只有value改变时才重渲染对应部分
const [item, setItem] = createSignal({ name: 'test', value: 100 });

<div>
  <span>{item().name}</span>        {/* name变化时只更新这里 */}
  <span>{item().value}</span>       {/* value变化时只更新这里 */}
</div>
```

### 2. 编译时优化

```typescript
// vite.config.ts - SolidJS编译优化
export default defineConfig({
  plugins: [solid()],
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['solid-js'],
          slices: ['./src/slices/*/index.ts'],
        },
      },
    },
  },
});
```

### 3. 并发无竞态设计

```typescript
// 使用SolidJS的批量更新避免竞态
import { batch } from 'solid-js';

const updateItems = async () => {
  const newItems = await itemsApi.list();
  
  // 批量更新，避免中间状态
  batch(() => {
    setLoading(false);
    setItems(newItems.items);
    setTotal(newItems.total);
  });
};
```

---

## 🔧 开发工作流

### 1. 新切片创建流程

```bash
# 1. 创建切片目录
mkdir web/slices/new_slice

# 2. 复制模板文件
cp web/slices/template/* web/slices/new_slice/

# 3. 同步backend类型
# 手动复制 backend/frontend/src/types/* -> web/slices/new_slice/types.ts

# 4. 同步API客户端
# 手动复制 backend/frontend/src/api/* -> web/slices/new_slice/api.ts
```

### 2. 类型同步策略

```typescript
// 使用脚本辅助类型同步检查
// scripts/sync-types.ts
const backendTypes = await import('../backend/frontend/src/types/api-runtime');
const frontendTypes = await import('../web/slices/items/types');

// 类型对比检查
assertTypesEqual(backendTypes.Item, frontendTypes.Item);
```

---

## 📊 架构优势对比

| 特性 | v7前端架构 | 传统架构 |
|-----|-----------|----------|
| **文件数量** | 4个核心文件 | 10+文件 |
| **运行时开销** | 零虚拟DOM | 虚拟DOM对比 |
| **类型安全** | 编译时检查 | 运行时检查 |
| **响应式粒度** | 信号级别 | 组件级别 |
| **代码分割** | 自动切片级 | 手动配置 |
| **构建体积** | 最小化 | 较大框架开销 |

---

## 🚀 最终效果

### 切片使用示例

```typescript
// 在应用中使用切片
import { ItemsView, useItems } from './slices/items';

const App = () => (
  <div>
    <ItemsView />  {/* 独立使用 */}
  </div>
);

// 或者在其他组件中使用逻辑
const Dashboard = () => {
  const { items, loading } = useItems();  // 复用逻辑
  
  return <div>Total items: {items().length}</div>;
};
```

---

## 🎯 核心价值

1. **轻量化**：最少文件、最小依赖、最简API
2. **高性能**：SolidJS零开销、编译时优化、细粒度更新
3. **稳定性**：TypeScript类型安全、手动同步可控
4. **可扩展**：清晰分层、独立切片、标准接口
5. **无竞态**：Signal批量更新、原子操作保证

通过这套 v7 前端范式，实现与后端完美匹配的轻量化、高性能前端架构。