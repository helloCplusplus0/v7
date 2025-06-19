# 📋 Web v7.1 前端开发范式设计文档

**基于 v7 反思的轻量化增强版**，解决切片通信、类型同步、标准化等核心问题。

---

## 🎯 v7.1 核心原则

### 平衡轻量化与完整性

| v7 原则 | v7.1 增强 | 设计理念 |
|---------|-----------|----------|
| Signal-first Components | **+ 标准化异步状态** | 保持轻量但统一模式 |
| 4文件极简结构 | **+ 共享层支撑** | 切片简洁，公共复用 |
| 手动类型同步 | **+ 自动化工具** | 开发体验与安全并重 |
| 独立切片设计 | **+ 切片间通信** | 独立性与协作并存 |

---

## 📁 v7.1 增强架构

### 1. 整体目录结构

```typescript
web/
├── shared/                    // 🆕 共享基础设施
│   ├── stores/               // 全局状态管理
│   │   ├── auth.ts
│   │   └── notification.ts
│   ├── hooks/                // 通用业务hooks
│   │   ├── useAsync.ts
│   │   └── useLocalStorage.ts
│   ├── api/                  // 基础API设施  
│   │   ├── base.ts
│   │   └── types.ts
│   ├── utils/                // 工具函数
│   └── types/                // 全局类型
├── slices/{slice_name}/      // 保持4文件结构
│   ├── types.ts
│   ├── api.ts  
│   ├── hooks.ts
│   ├── view.tsx
│   └── index.ts
├── scripts/                   // 🆕 自动化工具
│   ├── sync-types.ts
│   └── generate-api.ts
└── tests/                     // 🆕 测试基础设施
    ├── shared/
    └── slices/
```

### 2. 切片结构保持简洁

切片内部仍然保持4文件结构，复杂度通过共享层解决。

---

## 🔄 问题1解决：自动化类型同步

### 类型同步自动化工具

```typescript
// scripts/sync-types.ts
interface TypeSyncConfig {
  backend: string;
  frontend: string;
  transform?: (type: any) => any;
}

const syncConfigs: TypeSyncConfig[] = [
  {
    backend: 'backend/frontend/src/types/api-runtime.ts',
    frontend: 'web/slices/items/types.ts',
    transform: (type) => ({
      ...type,
      // 前端特定转换（如日期字符串处理）
      created_at: 'string',
      updated_at: 'string'
    })
  }
];

// 自动生成前端类型
export async function syncTypes() {
  for (const config of syncConfigs) {
    const backendTypes = await parseTypeFile(config.backend);
    const frontendTypes = config.transform 
      ? config.transform(backendTypes) 
      : backendTypes;
    
    await generateTypeFile(config.frontend, frontendTypes);
    console.log(`✅ 已同步: ${config.frontend}`);
  }
}
```

### package.json 脚本集成

```json
{
  "scripts": {
    "sync:types": "tsx scripts/sync-types.ts",
    "dev": "npm run sync:types && vite",
    "build": "npm run sync:types && vite build"
  }
}
```

---

## 🔄 问题2解决：切片间通信机制

### 全局状态管理

```typescript
// shared/stores/auth.ts - 用户认证全局状态
import { createSignal, createContext, useContext } from 'solid-js';

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
}

const [authState, setAuthState] = createSignal<AuthState>({
  user: null,
  token: null,
  isAuthenticated: false
});

export const AuthContext = createContext({
  state: authState,
  login: async (credentials: LoginRequest) => {
    const response = await authApi.login(credentials);
    setAuthState({
      user: response.user,
      token: response.token,
      isAuthenticated: true
    });
  },
  logout: () => setAuthState({
    user: null,
    token: null,
    isAuthenticated: false
  })
});

// 便捷hook
export const useAuth = () => useContext(AuthContext);
```

### 切片中使用全局状态

```typescript
// slices/profile/hooks.ts
import { useAuth } from '../../shared/stores/auth';

export function useProfile() {
  const { state: authState } = useAuth();
  
  const [profileResource] = createResource(
    () => authState().user?.id,
    async (userId) => {
      if (!userId) return null;
      return profileApi.getProfile(userId);
    }
  );
  
  return { profile: profileResource };
}
```

---

## 🔄 问题3解决：标准化异步状态

### 统一异步状态管理

```typescript
// shared/hooks/useAsync.ts
interface AsyncState<T> {
  data: T | null;
  loading: boolean;
  error: Error | null;
}

export function useAsync<T>(
  fetcher: () => Promise<T>,
  deps?: () => any[]
) {
  const [state, setState] = createSignal<AsyncState<T>>({
    data: null,
    loading: true,
    error: null
  });
  
  const execute = async () => {
    setState(prev => ({ ...prev, loading: true, error: null }));
    
    try {
      const data = await fetcher();
      setState({ data, loading: false, error: null });
      return data;
    } catch (error) {
      setState(prev => ({ 
        ...prev, 
        loading: false, 
        error: error as Error 
      }));
      throw error;
    }
  };
  
  // 依赖变化时自动执行
  createEffect(() => {
    if (deps) deps();
    execute();
  });
  
  return {
    ...state(),
    execute,
    refetch: execute
  };
}
```

### 切片中使用标准化异步状态

```typescript
// slices/items/hooks.ts - 使用标准化模式
import { useAsync } from '../../shared/hooks/useAsync';
import { itemsApi } from './api';

export function useItems() {
  const { data: items, loading, error, refetch } = useAsync(
    () => itemsApi.list(),
    [] // 无依赖，仅执行一次
  );
  
  const createItem = async (data: CreateItemRequest) => {
    const newItem = await itemsApi.create(data);
    await refetch(); // 刷新列表
    return newItem;
  };
  
  return { items, loading, error, createItem, refetch };
}
```

---

## 🔄 问题4解决：API层标准化

### 基础API客户端

```typescript
// shared/api/base.ts
export class ApiError extends Error {
  constructor(
    public status: number,
    public message: string,
    public data?: any
  ) {
    super(message);
  }
}

export abstract class BaseApiClient {
  protected baseUrl = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000';
  
  protected async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    // 🔐 自动添加认证头
    const authToken = this.getAuthToken();
    const headers = {
      'Content-Type': 'application/json',
      ...(authToken && { Authorization: `Bearer ${authToken}` }),
      ...options.headers,
    };
    
    const url = `${this.baseUrl}${endpoint}`;
    const response = await fetch(url, { ...options, headers });
    
    if (!response.ok) {
      const errorData = await response.text();
      throw new ApiError(response.status, errorData);
    }
    
    return response.json();
  }
  
  private getAuthToken(): string | null {
    // 从全局状态或localStorage获取token
    return localStorage.getItem('auth_token');
  }
}
```

### 切片API继承基类

```typescript
// slices/items/api.ts - 继承标准化基类
import { BaseApiClient } from '../../shared/api/base';
import type { Item, CreateItemRequest, ListItemsResponse } from './types';

class ItemsApiClient extends BaseApiClient {
  async list(query?: ListItemsQuery): Promise<ListItemsResponse> {
    const params = new URLSearchParams();
    if (query?.limit) params.set('limit', String(query.limit));
    if (query?.offset) params.set('offset', String(query.offset));
    
    const endpoint = `/api/items${params.toString() ? `?${params}` : ''}`;
    return this.request<ListItemsResponse>(endpoint);
  }
  
  async create(data: CreateItemRequest): Promise<Item> {
    return this.request<Item>('/api/items', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }
}

export const itemsApi = new ItemsApiClient();
```

---

## 🔄 问题5解决：测试策略

### 测试基础设施

```typescript
// tests/shared/test-utils.tsx
import { render } from '@solidjs/testing-library';
import { AuthContext } from '../../shared/stores/auth';

// 测试用的认证Provider
export const TestAuthProvider = (props: { children: any }) => {
  const mockAuthState = createSignal({
    user: { id: '1', name: 'Test User' },
    token: 'mock-token',
    isAuthenticated: true
  });
  
  return (
    <AuthContext.Provider value={{
      state: mockAuthState[0],
      login: vi.fn(),
      logout: vi.fn()
    }}>
      {props.children}
    </AuthContext.Provider>
  );
};

// 辅助渲染函数
export const renderWithAuth = (ui: Component) => {
  return render(() => (
    <TestAuthProvider>
      {ui}
    </TestAuthProvider>
  ));
};
```

### 切片测试示例

```typescript
// slices/items/__tests__/hooks.test.ts
import { renderHook } from '@solidjs/testing-library';
import { useItems } from '../hooks';
import { TestAuthProvider } from '../../../tests/shared/test-utils';

describe('useItems', () => {
  test('should load items successfully', async () => {
    // Mock API
    vi.mocked(itemsApi.list).mockResolvedValue({
      items: [{ id: '1', name: 'Test Item' }],
      total: 1
    });
    
    const { result } = renderHook(() => useItems(), {
      wrapper: TestAuthProvider
    });
    
    await waitFor(() => {
      expect(result().loading).toBe(false);
      expect(result().items).toHaveLength(1);
    });
  });
});
```

---

## 🔧 v7.1 开发工作流

### 1. 项目初始化

```bash
# 1. 设置自动类型同步
npm run setup:sync

# 2. 启动开发服务器（自动同步类型）
npm run dev

# 3. 类型检查（CI中使用）
npm run type:check
```

### 2. 新切片创建

```bash
# 使用脚手架创建切片
npm run create:slice items

# 自动生成：
# - slices/items/types.ts（从backend同步）
# - slices/items/api.ts（基于BaseApiClient）
# - slices/items/hooks.ts（使用useAsync模板）
# - slices/items/view.tsx（SolidJS模板）
# - slices/items/__tests__/（测试模板）
```

---

## 📊 v7.1 架构优势

### 解决的核心问题

| 问题领域 | v7.0 状态 | v7.1 解决方案 | 效果 |
|----------|-----------|---------------|------|
| **类型同步** | 手动维护 | 自动化工具 | 零维护成本 |
| **切片通信** | 缺失 | 全局状态 + Context | 安全数据共享 |
| **异步状态** | 各自实现 | useAsync标准化 | 一致的用户体验 |
| **API层** | 简单fetch | BaseApiClient | 统一错误处理 |
| **测试** | 无策略 | 完整测试基础设施 | 质量保证 |

### 保持的轻量化特性

- ✅ 切片仍为4文件结构
- ✅ SolidJS零虚拟DOM开销
- ✅ 编译时类型检查
- ✅ 按需加载切片

---

## 🎯 v7.1 vs v7.0 对比

### 文件数量对比

```
v7.0: 4文件/切片
v7.1: 4文件/切片 + 共享基础设施

总体复杂度增加约30%，但解决了生产环境的关键问题
```

### 开发体验提升

```typescript
// v7.0 - 手动重复
const [loading, setLoading] = createSignal(false);
const [error, setError] = createSignal(null);
const [items, setItems] = createSignal([]);

// v7.1 - 标准化
const { items, loading, error, refetch } = useAsync(() => itemsApi.list());
```

---

## 🚀 迁移指南（v7.0 → v7.1）

### 1. 添加共享基础设施

```bash
mkdir -p web/shared/{stores,hooks,api,utils,types}
mkdir -p web/scripts
mkdir -p web/tests/shared
```

### 2. 现有切片增强

```typescript
// 原有的 hooks.ts
- const [loading, setLoading] = createSignal(false);
+ const { data: items, loading, error } = useAsync(() => itemsApi.list());
```

### 3. 设置自动化工具

```bash
npm install -D tsx @types/node
# 添加类型同步脚本
# 配置 package.json scripts
```

---

## 🎯 最终评价

### v7.1 解决的核心痛点

1. ✅ **可维护性**：自动化类型同步，消除手动维护负担
2. ✅ **架构完整性**：切片间通信机制，支持复杂应用场景  
3. ✅ **开发体验**：标准化模式，减少重复代码
4. ✅ **质量保证**：完整测试基础设施
5. ✅ **工程化**：自动化工具链支撑

### 保持的v7优势

1. ✅ **轻量化**：切片结构依然简洁
2. ✅ **高性能**：SolidJS核心优势保留
3. ✅ **类型安全**：TypeScript编译时检查
4. ✅ **可扩展**：模块化架构易于扩展

**v7.1 = v7的轻量化 + 生产环境的完整性**

这个版本在保持轻量化原则的基础上，解决了实际项目中的关键问题，是一个更加平衡和实用的架构设计。 