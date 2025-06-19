# Web Shared Infrastructure - v7.2 实现

## 🎯 概览

本目录实现了FMOD v7.2架构的四种解耦通信机制，为前端应用提供高质量、可维护的基础设施。

## 📁 目录结构

```
shared/
├── events/                    # 🎯 事件驱动通信
│   ├── EventBus.ts           # 零依赖事件总线
│   └── events.types.ts       # 事件类型定义
├── contracts/                # 🎯 契约接口
│   ├── AuthContract.ts       # 认证契约
│   ├── NotificationContract.ts # 通知契约
│   └── index.ts              # 契约映射
├── signals/                  # 🎯 响应式状态
│   ├── AppSignals.ts         # 全局信号定义
│   └── accessors.ts          # 访问器模式
├── providers/                # 🎯 依赖注入
│   ├── ContractProvider.tsx  # 契约提供者
│   └── SliceProvider.tsx     # 切片提供者
├── hooks/                    # 标准化 hooks
│   ├── useAsync.ts           # 异步操作hook
│   ├── useLocalStorage.ts    # 本地存储hook
│   └── useDebounce.ts        # 防抖hook（新增）
├── api/                      # 基础 API 设施
│   ├── base.ts               # 基础API客户端
│   ├── types.ts              # API类型定义
│   └── interceptors.ts       # API拦截器（新增）
└── utils/                    # 工具函数
    └── index.ts              # 实用工具集合
```

## 🔄 四种解耦通信机制

### 1. 事件驱动通信 - 一次性事件
- **用途**：切片间松耦合通信
- **特点**：发布者不知道订阅者，订阅者不依赖发布者
- **实现**：`EventBus.ts` + `events.types.ts`

```typescript
// 发布事件
eventBus.emit('auth:login', { user, token });

// 订阅事件
const unsubscribe = eventBus.on('auth:login', ({ user }) => {
  console.log(`Welcome ${user.name}!`);
});
```

### 2. 契约接口 - 服务调用
- **用途**：跨切片服务调用
- **特点**：依赖接口而非具体实现，支持依赖注入
- **实现**：`contracts/` + `ContractProvider.tsx`

```typescript
// 使用契约
const authContract = useContract('auth');
const user = authContract.getCurrentUser();
```

### 3. 信号响应式 - 状态订阅
- **用途**：全局状态管理和响应式更新
- **特点**：基于SolidJS信号系统，自动响应式更新
- **实现**：`AppSignals.ts` + `accessors.ts`

```typescript
// 使用访问器
const userAccessor = createUserAccessor();
const user = userAccessor.getUser();
userAccessor.setUser(newUser);
```

### 4. Provider模式 - 依赖管理
- **用途**：服务注册和依赖注入
- **特点**：支持运行时切换实现，测试友好
- **实现**：`SliceProvider.tsx`

```typescript
// 注册服务
<ContractProvider contracts={{ auth: authService, notification: notificationService }}>
  <App />
</ContractProvider>
```

## 🚀 新增功能（本次改进）

### API 拦截器系统
- **文件**：`api/interceptors.ts`
- **功能**：请求/响应拦截、日志记录、性能监控、Token刷新
- **使用**：
```typescript
const client = new ApiClient();
client.addRequestInterceptor(createLoggingInterceptor());
client.addResponseInterceptor(createTokenRefreshInterceptor(refreshToken));
```

### 增强 Hooks 集合
- **文件**：`hooks/useDebounce.ts`
- **功能**：
  - `useDebounce()` - 值防抖
  - `useDebouncedCallback()` - 函数防抖
  - `useSearch()` - 搜索防抖专用

```typescript
const [search, setSearch] = createSignal('');
const debouncedSearch = useDebounce(search, 300);

const searchHook = useSearch('', 500);
searchHook.setSearchInput('query');
```

## 📊 测试覆盖率

| 模块 | 测试文件 | 测试用例 | 状态 |
|------|----------|----------|------|
| EventBus | `events/EventBus.test.ts` | 12 | ✅ |
| Signals | `signals/signals.test.ts` | 10 | ✅ |
| Contracts | `contracts/contracts.test.ts` | 11 | ✅ |
| Providers | `providers/providers.test.ts` | 10 | ✅ |
| Utils | `utils/utils.test.ts` | 30 | ✅ |
| Hooks | `hooks/hooks.test.ts` | 11 | ✅ |
| API | `api/base.test.ts` | 8 | ✅ |
| Advanced Hooks | `hooks/advanced-hooks.test.ts` | 8 | ✅ |
| Integration | `integration.test.ts` | 6 | ✅ |

**总计**：106+ 测试用例，覆盖所有核心功能

## 🎯 最佳实践

### 1. 通信机制选择指南
- **事件总线**：一次性通知、跨切片广播
- **契约接口**：需要返回值的服务调用
- **信号状态**：全局状态管理、响应式UI更新
- **Provider**：服务配置、依赖注入

### 2. 切片独立性
- 每个切片应该能够独立测试和运行
- 通过基础设施通信，不直接依赖其他切片
- 使用类型安全的接口定义

### 3. 错误处理
- 事件处理器中的错误不会影响其他监听器
- API错误通过统一的ErrorHandler处理
- 提供有意义的错误上下文和恢复建议

### 4. 性能优化
- 使用防抖减少频繁更新
- 信号系统提供细粒度响应式更新
- API拦截器支持性能监控

## 🔧 使用示例

### 完整的用户登录流程
```typescript
// 1. 登录操作（auth切片）
const login = async (credentials) => {
  const user = await authApi.login(credentials);
  
  // 2. 更新全局状态（信号）
  userAccessor.setUser(user);
  
  // 3. 发布事件通知（事件总线）
  eventBus.emit('auth:login', { user, token: user.token });
  
  // 4. 显示通知（契约接口）
  notificationContract.show(`欢迎回来，${user.name}！`, 'success');
};

// 其他切片响应登录事件
eventBus.on('auth:login', ({ user }) => {
  // 更新用户相关UI
  updateUserProfile(user);
});
```

## 📈 架构优势

1. **类型安全**：完整的TypeScript支持，编译时错误检查
2. **零耦合**：切片间无直接依赖，通过基础设施通信
3. **可测试性**：支持依赖注入和mock，单元测试友好
4. **可扩展性**：模块化设计，易于添加新功能
5. **性能优化**：细粒度响应式更新，避免不必要的渲染
6. **开发体验**：丰富的工具和hooks，提升开发效率

---

这个基础设施为FMOD v7.2架构提供了坚实的基础，确保了代码的高质量、可维护性和可扩展性。 