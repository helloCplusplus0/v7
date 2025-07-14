// 🧪 MVP CRUD - 测试工具和模拟数据
// 为MVP CRUD切片提供标准化的测试工具

import { vi } from 'vitest';
import type { Item, CreateItemRequest, UpdateItemRequest } from '../../../slices/mvp_crud/types';
import type { GrpcResponse } from '../../../shared/api/grpc-client';

// ===== 模拟数据生成器 =====

/**
 * 生成模拟项目数据
 */
export function createMockItem(overrides?: Partial<Item>): Item {
  const id = overrides?.id || `item-${Math.random().toString(36).substr(2, 9)}`;
  const now = new Date().toISOString();
  
  return {
    id,
    name: `测试项目 ${id.slice(-4)}`,
    description: `这是一个测试项目的描述 ${id}`,
    value: Math.floor(Math.random() * 1000) + 1,
    createdAt: now,
    updatedAt: now,
    ...overrides
  };
}

/**
 * 生成多个模拟项目
 */
export function createMockItems(count: number, overrides?: Partial<Item>): Item[] {
  return Array.from({ length: count }, (_, index) => 
    createMockItem({ 
      name: `测试项目 ${index + 1}`,
      value: (index + 1) * 100,
      ...overrides 
    })
  );
}

/**
 * 生成模拟创建请求
 */
export function createMockCreateRequest(overrides?: Partial<CreateItemRequest>): CreateItemRequest {
  return {
    name: `新项目 ${Date.now()}`,
    description: '新项目的描述',
    value: 500,
    ...overrides
  };
}

/**
 * 生成模拟更新请求
 */
export function createMockUpdateRequest(overrides?: Partial<UpdateItemRequest>): UpdateItemRequest {
  return {
    name: '更新后的项目名称',
    description: '更新后的项目描述',
    value: 750,
    ...overrides
  };
}

// ===== gRPC响应模拟器 =====

/**
 * 创建成功的gRPC响应
 */
export function createSuccessResponse<T>(data: T): GrpcResponse<T> {
  return {
    success: true,
    data,
    metadata: {
      method: 'test',
      timestamp: new Date().toISOString()
    }
  };
}

/**
 * 创建失败的gRPC响应
 */
export function createErrorResponse(error: string): GrpcResponse<any> {
  return {
    success: false,
    error,
    metadata: {
      method: 'test',
      timestamp: new Date().toISOString()
    }
  };
}

// ===== API模拟器 =====

/**
 * 创建模拟的CrudApiClient
 */
export function createMockCrudApi() {
  return {
    // 基本CRUD操作
    createItem: vi.fn(),
    getItem: vi.fn(),
    updateItem: vi.fn(),
    deleteItem: vi.fn(),
    listItems: vi.fn(),
    
    // 批量操作
    batchDeleteItems: vi.fn(),
    
    // 健康检查
    healthCheck: vi.fn(),
    
    // 测试兼容性方法
    checkHealth: vi.fn(),
    list: vi.fn(),
    create: vi.fn(),
    get: vi.fn(),
    update: vi.fn(),
    delete: vi.fn()
  };
}

/**
 * 配置模拟API的默认行为
 */
export function configureMockApi(mockApi: ReturnType<typeof createMockCrudApi>) {
  // 默认成功响应
  const mockItem = createMockItem();
  const mockItems = createMockItems(3);
  
  mockApi.createItem.mockResolvedValue(mockItem);
  mockApi.getItem.mockResolvedValue(mockItem);
  mockApi.updateItem.mockResolvedValue(mockItem);
  mockApi.deleteItem.mockResolvedValue(undefined);
  mockApi.listItems.mockResolvedValue({
    items: mockItems,
    total: mockItems.length
  });
  
  mockApi.batchDeleteItems.mockResolvedValue({
    success: 3,
    failed: 0,
    errors: []
  });
  
  mockApi.healthCheck.mockResolvedValue(true);
  
  // 测试兼容性方法
  mockApi.checkHealth.mockResolvedValue(true);
  mockApi.list.mockResolvedValue({
    success: true,
    data: mockItems,
    total: mockItems.length
  });
  mockApi.create.mockResolvedValue({
    success: true,
    data: mockItem
  });
  mockApi.get.mockResolvedValue({
    success: true,
    data: mockItem
  });
  mockApi.update.mockResolvedValue({
    success: true,
    data: mockItem
  });
  mockApi.delete.mockResolvedValue({
    success: true
  });
  
  return mockApi;
}

// ===== 事件模拟器 =====

/**
 * 创建模拟的EventBus
 */
export function createMockEventBus() {
  const listeners = new Map<string, Array<(...args: any[]) => void>>();
  
  return {
    on: vi.fn((event: string, handler: (...args: any[]) => void) => {
      if (!listeners.has(event)) {
        listeners.set(event, []);
      }
      listeners.get(event)!.push(handler);
      
      // 返回取消订阅函数
      return () => {
        const eventListeners = listeners.get(event);
        if (eventListeners) {
          const index = eventListeners.indexOf(handler);
          if (index !== -1) {
            eventListeners.splice(index, 1);
          }
        }
      };
    }),
    
    once: vi.fn((event: string, handler: (...args: any[]) => void) => {
      const onceHandler = (...args: any[]) => {
        handler(...args);
        // 自动移除
        const eventListeners = listeners.get(event);
        if (eventListeners) {
          const index = eventListeners.indexOf(onceHandler);
          if (index !== -1) {
            eventListeners.splice(index, 1);
          }
        }
      };
      
      if (!listeners.has(event)) {
        listeners.set(event, []);
      }
      listeners.get(event)!.push(onceHandler);
      
      return () => {};
    }),
    
    emit: vi.fn((event: string, data: any) => {
      const eventListeners = listeners.get(event);
      if (eventListeners) {
        eventListeners.forEach(handler => {
          try {
            handler(data);
          } catch (error) {
            console.error('Mock EventBus handler error:', error);
          }
        });
      }
    }),
    
    off: vi.fn(),
    removeAllListeners: vi.fn(() => {
      listeners.clear();
    }),
    
    // 测试辅助方法
    getListeners: () => listeners,
    hasListeners: (event: string) => listeners.has(event) && listeners.get(event)!.length > 0
  };
}

// ===== 信号模拟器 =====

/**
 * 创建模拟的访问器
 */
export function createMockAccessors() {
  return {
    userAccessor: {
      getUser: vi.fn(() => null),
      setUser: vi.fn(),
      isAuthenticated: vi.fn(() => false),
      getUserId: vi.fn(() => null)
    },
    
    notificationAccessor: {
      getNotifications: vi.fn(() => []),
      setNotifications: vi.fn(),
      addNotification: vi.fn(),
      removeNotification: vi.fn(),
      clearNotifications: vi.fn()
    }
  };
}

// ===== 测试断言辅助 =====

/**
 * 验证项目对象结构
 */
export function expectValidItem(item: any) {
  expect(item).toMatchObject({
    id: expect.any(String),
    name: expect.any(String),
    value: expect.any(Number),
    createdAt: expect.any(String),
    updatedAt: expect.any(String)
  });
  
  expect(item.id).toBeTruthy();
  expect(item.name).toBeTruthy();
  expect(item.value).toBeGreaterThanOrEqual(0);
  expect(new Date(item.createdAt)).toBeInstanceOf(Date);
  expect(new Date(item.updatedAt)).toBeInstanceOf(Date);
}

/**
 * 验证项目列表响应
 */
export function expectValidItemsResponse(response: { items: Item[]; total: number }) {
  expect(response).toMatchObject({
    items: expect.any(Array),
    total: expect.any(Number)
  });
  
  expect(response.total).toBeGreaterThanOrEqual(0);
  expect(response.items.length).toBeLessThanOrEqual(response.total);
  
  response.items.forEach(item => {
    expectValidItem(item);
  });
}

/**
 * 验证gRPC响应结构
 */
export function expectValidGrpcResponse<T>(response: GrpcResponse<T>) {
  expect(response).toMatchObject({
    success: expect.any(Boolean)
  });
  
  if (response.success) {
    expect(response.data).toBeDefined();
  } else {
    expect(response.error).toBeDefined();
    expect(typeof response.error).toBe('string');
  }
}

// ===== 性能测试工具 =====

/**
 * 测量函数执行时间
 */
export async function measureExecutionTime<T>(
  fn: () => Promise<T> | T,
  expectedMaxTime?: number
): Promise<{ result: T; executionTime: number }> {
  const startTime = performance.now();
  const result = await fn();
  const endTime = performance.now();
  const executionTime = endTime - startTime;
  
  if (expectedMaxTime !== undefined) {
    expect(executionTime).toBeLessThan(expectedMaxTime);
  }
  
  return { result, executionTime };
}

/**
 * 等待指定时间
 */
export function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * 等待条件满足
 */
export async function waitFor(
  condition: () => boolean,
  timeout = 1000,
  interval = 10
): Promise<void> {
  const startTime = Date.now();
  
  while (!condition()) {
    if (Date.now() - startTime > timeout) {
      throw new Error(`Condition not met within ${timeout}ms`);
    }
    await delay(interval);
  }
}

// ===== 错误模拟器 =====

/**
 * 创建模拟错误
 */
export function createMockError(message: string, code?: string) {
  const error = new Error(message);
  if (code) {
    (error as any).code = code;
  }
  return error;
}

/**
 * 模拟网络错误
 */
export function createNetworkError() {
  return createMockError('Network error', 'NETWORK_ERROR');
}

/**
 * 模拟超时错误
 */
export function createTimeoutError() {
  return createMockError('Request timeout', 'TIMEOUT');
}

/**
 * 模拟验证错误
 */
export function createValidationError(field: string) {
  return createMockError(`Validation failed for field: ${field}`, 'VALIDATION_ERROR');
}

// ===== 测试数据常量 =====

export const TEST_CONSTANTS = {
  // 测试超时
  DEFAULT_TIMEOUT: 5000,
  FAST_TIMEOUT: 1000,
  SLOW_TIMEOUT: 10000,
  
  // 性能基准
  MAX_API_RESPONSE_TIME: 2000,
  MAX_UI_RENDER_TIME: 100,
  MAX_SEARCH_TIME: 500,
  
  // 数据限制
  MAX_ITEMS_PER_PAGE: 50,
  MIN_ITEMS_PER_PAGE: 1,
  MAX_ITEM_NAME_LENGTH: 100,
  MAX_ITEM_DESCRIPTION_LENGTH: 500,
  
  // 测试数据
  VALID_ITEM_NAME: '有效的项目名称',
  INVALID_ITEM_NAME: '', // 空字符串
  LONG_ITEM_NAME: 'A'.repeat(101), // 超长名称
  VALID_ITEM_VALUE: 100,
  INVALID_ITEM_VALUE: -1, // 负数
  LARGE_ITEM_VALUE: 999999
} as const;

// 导出类型
export type MockCrudApi = ReturnType<typeof createMockCrudApi>;
export type MockEventBus = ReturnType<typeof createMockEventBus>;
export type MockAccessors = ReturnType<typeof createMockAccessors>; 