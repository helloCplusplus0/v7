# 📋 Web v7.2 前端开发范式设计文档

**基于切片独立性原则的轻量化架构**，实现零编译时依赖的切片间通信。

---

## 🎯 v7.2 核心原则

### 切片独立性 First

| 架构原则 | v7.2 实现 | 设计目标 |
|----------|-----------|----------|
| **Zero Coupling** | 零编译时依赖 | 切片间不能有直接 import |
| **Contract First** | 接口抽象 | 依赖契约，不依赖实现 |
| **Event Driven** | 事件总线通信 | 发布者不知道订阅者 |
| **Signal Reactive** | 响应式状态 | 细粒度更新，松耦合 |

### 前后端解耦对应关系

| 后端 Rust 特性 | 前端 TypeScript 对应 | 解耦效果 |
|---------------|---------------------|----------|
| Trait 接口抽象 | **Contract Interface** | 依赖倒置 |
| Channel 消息传递 | **EventBus 事件驱动** | 异步解耦 |
| Clone 静态分发 | **Signal 响应式** | 零运行时开销 |
| Generic 泛型约束 | **Accessor 访问器** | 类型安全解耦 |

---

## 📁 v7.2 架构设计

### 1. 目录结构

```typescript
web/
├── shared/                    // 解耦基础设施
│   ├── events/               // 🎯 事件驱动通信
│   │   ├── EventBus.ts       // 零依赖事件总线
│   │   └── events.types.ts   // 事件类型定义
│   ├── contracts/            // 🎯 契约接口
│   │   ├── AuthContract.ts
│   │   ├── NotificationContract.ts
│   │   └── index.ts
│   ├── signals/              // 🎯 响应式状态
│   │   ├── AppSignals.ts     // 全局信号定义
│   │   └── accessors.ts      // 访问器模式
│   ├── providers/            // 🎯 依赖注入
│   │   ├── ContractProvider.tsx
│   │   └── SliceProvider.tsx
│   ├── hooks/                // 标准化 hooks
│   │   ├── useAsync.ts
│   │   └── useLocalStorage.ts
│   ├── api/                  // 基础 API 设施
│   │   ├── base.ts
│   │   └── types.ts
│   └── utils/                // 工具函数
├── slices/{slice_name}/      // 保持 4 文件结构
│   ├── types.ts              // 类型定义（自动同步）
│   ├── api.ts                // API 客户端（继承基类）
│   ├── hooks.ts              // 业务逻辑（零依赖通信）
│   ├── view.tsx              // UI 组件（SolidJS）
│   └── index.ts              // 统一导出
├── scripts/                  // 自动化工具
│   ├── sync-types.ts
│   ├── create-slice.ts
│   └── check-dependencies.ts
└── tests/                    // 测试基础设施
    ├── shared/
    └── slices/
```

### 2. 切片独立性验证

```bash
# ✅ 每个切片可以完全独立构建和测试
cd slices/profile && npm test    # 无外部依赖
cd slices/auth && npm test       # 完全隔离
cd slices/notification && npm test  # 独立运行
```

---

## 🔄 四种解耦通信机制

### 1. 事件驱动通信 - 一次性事件

```typescript
// shared/events/EventBus.ts - 零依赖事件总线
interface EventMap {
  'auth:login': { user: User; token: string };
  'auth:logout': {};
  'profile:updated': { userId: string; profile: Profile };
  'notification:show': { message: string; type: 'info' | 'error' | 'success' };
  'cart:item-added': { item: CartItem; total: number };
}

class EventBus {
  private listeners = new Map<keyof EventMap, Set<Function>>();
  
  // 发布事件 - 发布者不知道谁在监听
  emit<K extends keyof EventMap>(event: K, data: EventMap[K]): void {
    const handlers = this.listeners.get(event);
    if (handlers) {
      handlers.forEach(handler => {
        try {
          handler(data);
        } catch (error) {
          console.error(`Event handler error for ${String(event)}:`, error);
        }
      });
    }
  }
  
  // 订阅事件 - 订阅者不知道谁在发布
  on<K extends keyof EventMap>(
    event: K, 
    handler: (data: EventMap[K]) => void
  ): () => void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event)!.add(handler);
    
    // 返回取消订阅函数
    return () => this.off(event, handler);
  }
  
  // 取消订阅
  off<K extends keyof EventMap>(event: K, handler: Function): void {
    this.listeners.get(event)?.delete(handler);
  }
  
  // 一次性监听
  once<K extends keyof EventMap>(
    event: K, 
    handler: (data: EventMap[K]) => void
  ): void {
    const onceHandler = (data: EventMap[K]) => {
      handler(data);
      this.off(event, onceHandler);
    };
    this.on(event, onceHandler);
  }
}

export const eventBus = new EventBus();
```

#### 切片使用示例

```typescript
// slices/auth/hooks.ts - 认证切片（事件发布者）
import { eventBus } from '../../shared/events/EventBus';

export function useAuth() {
  const [user, setUser] = createSignal<User | null>(null);
  
  const login = async (credentials: LoginRequest) => {
    const response = await authApi.login(credentials);
    setUser(response.user);
    
    // 🔄 发布登录事件 - 不知道谁在监听
    eventBus.emit('auth:login', {
      user: response.user,
      token: response.token
    });
  };
  
  const logout = () => {
    setUser(null);
    // 🔄 发布登出事件
    eventBus.emit('auth:logout', {});
  };
  
  return { user, login, logout };
}
```

```typescript
// slices/notification/hooks.ts - 通知切片（事件订阅者）
import { eventBus } from '../../shared/events/EventBus';

export function useNotification() {
  const [notifications, setNotifications] = createSignal<Notification[]>([]);
  
  // 🔄 监听各种事件 - 不依赖具体切片
  onMount(() => {
    const unsubscribers = [
      eventBus.on('auth:login', ({ user }) => {
        showNotification(`欢迎回来，${user.name}！`, 'success');
      }),
      
      eventBus.on('auth:logout', () => {
        showNotification('您已安全退出', 'info');
      }),
      
      eventBus.on('profile:updated', () => {
        showNotification('个人资料已更新', 'success');
      })
    ];
    
    // 清理函数
    onCleanup(() => {
      unsubscribers.forEach(unsub => unsub());
    });
  });
  
  const showNotification = (message: string, type: 'info' | 'error' | 'success') => {
    const notification = { id: Date.now(), message, type };
    setNotifications(prev => [...prev, notification]);
    
    // 3秒后自动移除
    setTimeout(() => {
      setNotifications(prev => prev.filter(n => n.id !== notification.id));
    }, 3000);
  };
  
  return { notifications, showNotification };
}
```

### 2. 契约接口 - 服务调用

```typescript
// shared/contracts/AuthContract.ts - 接口定义
export interface AuthContract {
  getCurrentUser(): User | null;
  isAuthenticated(): boolean;
  getToken(): string | null;
  login(credentials: LoginRequest): Promise<User>;
  logout(): Promise<void>;
}

export interface NotificationContract {
  show(message: string, type: 'info' | 'error' | 'success'): void;
  clear(): void;
  getNotifications(): Notification[];
}

// shared/contracts/index.ts - 契约映射
export interface ContractMap {
  auth: AuthContract;
  notification: NotificationContract;
}
```

```typescript
// shared/providers/ContractProvider.tsx - 依赖注入容器
import { createContext, useContext } from 'solid-js';
import type { ContractMap } from '../contracts';

const ContractContext = createContext<ContractMap>({} as ContractMap);

export function ContractProvider(props: { 
  contracts: ContractMap;
  children: any;
}) {
  return (
    <ContractContext.Provider value={props.contracts}>
      {props.children}
    </ContractContext.Provider>
  );
}

// 类型安全的契约获取
export function useContract<K extends keyof ContractMap>(
  contractName: K
): ContractMap[K] {
  const contracts = useContext(ContractContext);
  const contract = contracts[contractName];
  
  if (!contract) {
    throw new Error(`Contract '${String(contractName)}' not found. Make sure it's registered in ContractProvider.`);
  }
  
  return contract;
}
```

#### 切片使用示例

```typescript
// slices/profile/hooks.ts - 通过契约依赖，不依赖具体实现
import { useContract } from '../../shared/providers/ContractProvider';

export function useProfile() {
  const authContract = useContract('auth');  // 依赖接口，非具体切片
  const notificationContract = useContract('notification');
  
  const [profile, setProfile] = createSignal<Profile | null>(null);
  
  const loadCurrentUserProfile = async () => {
    try {
      const currentUser = authContract.getCurrentUser();
      if (!currentUser) {
        notificationContract.show('请先登录', 'error');
        return;
      }
      
      const profileData = await profileApi.get(currentUser.id);
      setProfile(profileData);
      notificationContract.show('个人资料加载成功', 'success');
    } catch (error) {
      notificationContract.show('加载个人资料失败', 'error');
    }
  };
  
  return { profile, loadCurrentUserProfile };
}
```

### 3. 信号响应式 - 状态订阅

```typescript
// shared/signals/AppSignals.ts - 全局信号定义
import { createSignal } from 'solid-js';

// 用户状态信号
export const [globalUser, setGlobalUser] = createSignal<User | null>(null);

// 主题状态信号
export const [globalTheme, setGlobalTheme] = createSignal<'light' | 'dark'>('light');

// 购物车状态信号
export const [globalCart, setGlobalCart] = createSignal<CartItem[]>([]);

// 通知状态信号
export const [globalNotifications, setGlobalNotifications] = createSignal<Notification[]>([]);
```

```typescript
// shared/signals/accessors.ts - 访问器模式，避免直接依赖
import { 
  globalUser, setGlobalUser,
  globalTheme, setGlobalTheme,
  globalCart, setGlobalCart,
  globalNotifications, setGlobalNotifications
} from './AppSignals';

// 用户访问器
export const createUserAccessor = () => ({
  getUser: globalUser,
  setUser: setGlobalUser,
  isAuthenticated: () => globalUser() !== null,
  getUserId: () => globalUser()?.id || null
});

// 主题访问器
export const createThemeAccessor = () => ({
  getTheme: globalTheme,
  setTheme: setGlobalTheme,
  toggleTheme: () => setGlobalTheme(prev => prev === 'light' ? 'dark' : 'light')
});

// 购物车访问器
export const createCartAccessor = () => ({
  getCart: globalCart,
  setCart: setGlobalCart,
  addItem: (item: CartItem) => setGlobalCart(prev => [...prev, item]),
  removeItem: (id: string) => setGlobalCart(prev => prev.filter(item => item.id !== id)),
  clearCart: () => setGlobalCart([]),
  getItemCount: () => globalCart().length,
  getTotalPrice: () => globalCart().reduce((sum, item) => sum + item.price * item.quantity, 0)
});
```

#### 切片使用示例

```typescript
// slices/auth/hooks.ts - 设置全局用户状态
import { createUserAccessor } from '../../shared/signals/accessors';

export function useAuth() {
  const userAccessor = createUserAccessor();
  
  const login = async (credentials: LoginRequest) => {
    const response = await authApi.login(credentials);
    // 设置全局用户状态 - 其他切片会自动响应
    userAccessor.setUser(response.user);
  };
  
  const logout = () => {
    userAccessor.setUser(null);
  };
  
  return { 
    user: userAccessor.getUser,
    login, 
    logout,
    isAuthenticated: userAccessor.isAuthenticated
  };
}
```

```typescript
// slices/header/hooks.ts - 响应用户状态变化
import { createUserAccessor } from '../../shared/signals/accessors';

export function useHeader() {
  const userAccessor = createUserAccessor();
  
  // 自动响应用户状态变化 - 无需手动监听
  const displayName = () => {
    const user = userAccessor.getUser();
    return user ? `欢迎，${user.name}` : '请登录';
  };
  
  const showUserMenu = userAccessor.isAuthenticated;
  
  return { displayName, showUserMenu };
}
```

### 4. 资源驱动 - 数据流

```typescript
// slices/profile/hooks.ts - 使用 createResource 响应依赖变化
import { createResource } from 'solid-js';
import { createUserAccessor } from '../../shared/signals/accessors';

export function useProfile() {
  const userAccessor = createUserAccessor();
  
  // 当用户变化时自动重新获取个人资料
  const [profile, { refetch, mutate }] = createResource(
    userAccessor.getUserId,  // 依赖：用户ID
    async (userId) => {
      if (!userId) return null;
      
      try {
        const profileData = await profileApi.get(userId);
        return profileData;
      } catch (error) {
        console.error('Failed to load profile:', error);
        throw error;
      }
    }
  );
  
  const updateProfile = async (updates: Partial<Profile>) => {
    const userId = userAccessor.getUserId();
    if (!userId) return;
    
    try {
      const updatedProfile = await profileApi.update(userId, updates);
      mutate(updatedProfile);  // 乐观更新
      
      // 发布更新事件
      eventBus.emit('profile:updated', { userId, profile: updatedProfile });
    } catch (error) {
      refetch();  // 失败时重新获取
      throw error;
    }
  };
  
  return { 
    profile, 
    updateProfile,
    isLoading: () => profile.loading,
    error: () => profile.error
  };
}
```

---

## 🏗️ 标准化基础设施

### 1. 统一异步状态管理

```typescript
// shared/hooks/useAsync.ts - 标准化异步状态
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
    loading: false,
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
    if (deps) {
      deps();  // 触发依赖计算
    }
    execute();
  });
  
  return {
    ...state(),
    execute,
    refetch: execute
  };
}
```

### 2. 基础 API 客户端

```typescript
// shared/api/base.ts - 统一 API 基类
export class ApiError extends Error {
  constructor(
    public status: number,
    public message: string,
    public data?: any
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export abstract class BaseApiClient {
  protected baseUrl = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000';
  
  protected async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    // 自动添加认证头
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
    // 从全局状态获取 token
    const userAccessor = createUserAccessor();
    const user = userAccessor.getUser();
    return user?.token || localStorage.getItem('auth_token');
  }
}
```

---

## 🎯 最佳实践指南

### 1. 切片通信选择

```typescript
// ✅ 使用事件驱动 - 适用于一次性通知
eventBus.emit('user:login', { user });

// ✅ 使用契约接口 - 适用于服务调用
const authContract = useContract('auth');
const user = authContract.getCurrentUser();

// ✅ 使用信号响应式 - 适用于状态订阅
const userAccessor = createUserAccessor();
const user = userAccessor.getUser(); // 自动响应变化

// ✅ 使用资源驱动 - 适用于数据依赖
const [profile] = createResource(userAccessor.getUserId, fetchProfile);
```

### 2. 避免的反模式

```typescript
// ❌ 直接切片依赖
import { useAuth } from '../auth/hooks';

// ❌ 紧耦合状态管理
import { globalAuthState } from '../../shared/store';

// ❌ 硬编码切片引用
const authSlice = registry.getSlice('auth');
```

---

## 🚀 开发工作流

### 1. 项目初始化

```bash
# 1. 安装依赖和设置自动化
npm install && npm run setup

# 2. 同步类型并启动开发服务器
npm run dev

# 3. 依赖检查（CI 中使用）
npm run check:dependencies
```

### 2. 新切片创建流程

```bash
# 1. 使用脚手架创建切片
npm run create:slice user-settings

# 2. 自动生成文件结构
# slices/user-settings/
# ├── types.ts (从 backend 同步)
# ├── api.ts (继承 BaseApiClient)
# ├── hooks.ts (零依赖通信模板)
# ├── view.tsx (SolidJS 组件模板)
# └── index.ts (统一导出)

# 3. 验证切片独立性
npm run check:dependencies
```

---

## 📊 v7.2 架构优势

### 解耦效果对比

| 方面 | v7.1 直接依赖 | v7.2 解耦通信 | 改进效果 |
|------|---------------|---------------|----------|
| **编译时依赖** | 切片间直接 import | 零 import 依赖 | ✅ 完全独立 |
| **测试隔离** | 需要 mock 其他切片 | 切片独立测试 | ✅ 测试简化 |
| **开发并行** | 切片间相互阻塞 | 并行开发 | ✅ 效率提升 |
| **部署独立** | 整体部署 | 切片级部署 | ✅ 灵活部署 |
| **错误隔离** | 一个切片错误影响全局 | 错误局部化 | ✅ 系统稳定 |

### 性能特性保持

- ✅ **SolidJS 零虚拟 DOM 开销**：保持细粒度响应式更新
- ✅ **编译时优化**：TypeScript 静态类型检查
- ✅ **Tree Shaking**：未使用的切片自动移除
- ✅ **按需加载**：切片级代码分割

---

## 🏁 总结

### v7.2 = 切片独立性 + 轻量化架构

1. **✅ 零编译时依赖**：切片间通过事件、契约、信号通信
2. **✅ 完全独立开发**：每个切片可以独立构建、测试、部署
3. **✅ 保持轻量化**：4 文件结构 + 共享基础设施
4. **✅ 高性能保证**：SolidJS 零开销 + 编译时优化
5. **✅ 工程化完善**：自动化类型同步 + 依赖检查

### 核心价值

- **🎯 架构一致性**：与后端 Rust 切片架构保持一致的解耦原则
- **⚡ 开发效率**：并行开发、独立测试、快速迭代
- **🛡️ 系统稳定**：错误隔离、局部化故障
- **📈 可扩展性**：新切片零成本添加、旧切片无缝移除

**Web v7.2 实现了真正意义上的切片架构**：**高内聚、低耦合、零依赖**，为现代前端开发提供了一套完整的解决方案。 