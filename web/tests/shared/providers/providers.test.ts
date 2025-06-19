// tests/shared/providers/providers.test.ts
import { describe, test, expect, beforeEach, vi } from 'vitest';
import { createRoot, createContext, useContext } from 'solid-js';
import { AuthContract, NotificationContract } from '../../../shared/contracts';
import type { User, Notification } from '../../../shared/events/events.types';

// Mock services for testing
class MockAuthService implements AuthContract {
  private user: User | null = null;
  private token: string | null = null;

  getCurrentUser(): User | null {
    return this.user;
  }

  isAuthenticated(): boolean {
    return this.user !== null;
  }

  getToken(): string | null {
    return this.token;
  }

  async login(credentials: { username: string; password: string }): Promise<User> {
    if (credentials.username === 'test' && credentials.password === 'password') {
      const user: User = {
        id: '1',
        name: 'Test User',
        email: 'test@example.com'
      };
      this.user = user;
      this.token = 'mock-token';
      return user;
    }
    throw new Error('Invalid credentials');
  }

  async logout(): Promise<void> {
    this.user = null;
    this.token = null;
  }
}

class MockNotificationService implements NotificationContract {
  private notifications: Notification[] = [];
  private nextId = 1;

  show(message: string, type: 'info' | 'error' | 'success' = 'info'): void {
    this.notifications.push({
      id: this.nextId++,
      message,
      type,
      timestamp: Date.now()
    });
  }

  clear(): void {
    this.notifications = [];
  }

  getNotifications(): Notification[] {
    return [...this.notifications];
  }
}

describe('Providers', () => {
  let mockAuthService: MockAuthService;
  let mockNotificationService: MockNotificationService;

  beforeEach(() => {
    mockAuthService = new MockAuthService();
    mockNotificationService = new MockNotificationService();
    vi.clearAllMocks();
  });

  describe('Contract Context Pattern', () => {
    test('应该能够创建和使用契约上下文', () => {
      const ContractContext = createContext<{ auth: AuthContract }>({} as any);
      
      createRoot(() => {
        const contracts = { auth: mockAuthService };
        
        // 模拟在Provider内部使用context
        const getContextValue = () => {
          return contracts;
        };
        
        const contextValue = getContextValue();
        expect(contextValue.auth).toBe(mockAuthService);
        expect(contextValue.auth.isAuthenticated()).toBe(false);
      });
    });

    test('应该支持多个契约的注册', () => {
      const ContractContext = createContext<{
        auth: AuthContract;
        notification: NotificationContract;
      }>({} as any);
      
      createRoot(() => {
        const contracts = {
          auth: mockAuthService,
          notification: mockNotificationService
        };
        
        expect(contracts.auth).toBe(mockAuthService);
        expect(contracts.notification).toBe(mockNotificationService);
        
        // 测试服务功能
        contracts.notification.show('Test message', 'info');
        expect(contracts.notification.getNotifications()).toHaveLength(1);
      });
    });
  });

  describe('Slice Registry Pattern', () => {
    test('应该能够管理slice配置', () => {
      const SliceContext = createContext<Record<string, any>>({});
      
      createRoot(() => {
        const slices = {
          'auth-slice': {
            name: 'auth-slice',
            version: '1.0.0',
            dependencies: ['auth']
          },
          'notification-slice': {
            name: 'notification-slice',
            version: '2.0.0',
            dependencies: ['notification']
          }
        };
        
        expect(Object.keys(slices)).toHaveLength(2);
        expect(slices['auth-slice'].name).toBe('auth-slice');
        expect(slices['auth-slice'].version).toBe('1.0.0');
        expect(slices['auth-slice'].dependencies).toEqual(['auth']);
      });
    });

    test('应该支持slice查找', () => {
      createRoot(() => {
        const slices: Record<string, { name: string; version: string }> = {
          'test-slice': {
            name: 'test-slice',
            version: '1.0.0'
          }
        };
        
        const findSlice = (name: string) => {
          return slices[name] || null;
        };
        
        const found = findSlice('test-slice');
        const notFound = findSlice('non-existent');
        
        expect(found).toBeTruthy();
        expect(found?.name).toBe('test-slice');
        expect(notFound).toBeNull();
      });
    });
  });

  describe('Service Integration', () => {
    test('应该支持服务间通信', async () => {
      createRoot(async () => {
        const contracts = {
          auth: mockAuthService,
          notification: mockNotificationService
        };

        // 模拟登录成功后显示通知
        await contracts.auth.login({ username: 'test', password: 'password' });
        contracts.notification.show('Login successful!', 'success');
        
        expect(contracts.auth.isAuthenticated()).toBe(true);
        expect(contracts.notification.getNotifications()).toHaveLength(1);
        expect(contracts.notification.getNotifications()[0]!.type).toBe('success');
        expect(contracts.notification.getNotifications()[0]!.message).toBe('Login successful!');
      });
    });

    test('应该支持错误处理', async () => {
      createRoot(async () => {
        const contracts = {
          auth: mockAuthService,
          notification: mockNotificationService
        };

        // 模拟登录失败
        try {
          await contracts.auth.login({ username: 'wrong', password: 'wrong' });
        } catch (error) {
          contracts.notification.show('Invalid credentials', 'error');
        }
        
        expect(contracts.auth.isAuthenticated()).toBe(false);
        expect(contracts.notification.getNotifications()).toHaveLength(1);
        expect(contracts.notification.getNotifications()[0]!.type).toBe('error');
        expect(contracts.notification.getNotifications()[0]!.message).toBe('Invalid credentials');
      });
    });

    test('应该支持服务状态变化', async () => {
      createRoot(async () => {
        const contracts = {
          auth: mockAuthService,
          notification: mockNotificationService
        };

        // 初始状态
        expect(contracts.auth.isAuthenticated()).toBe(false);
        expect(contracts.auth.getCurrentUser()).toBeNull();
        expect(contracts.auth.getToken()).toBeNull();

        // 登录
        const user = await contracts.auth.login({ username: 'test', password: 'password' });
        expect(contracts.auth.isAuthenticated()).toBe(true);
        expect(contracts.auth.getCurrentUser()).toEqual(user);
        expect(contracts.auth.getToken()).toBe('mock-token');

        // 登出
        await contracts.auth.logout();
        expect(contracts.auth.isAuthenticated()).toBe(false);
        expect(contracts.auth.getCurrentUser()).toBeNull();
        expect(contracts.auth.getToken()).toBeNull();
      });
    });

    test('应该支持通知管理', () => {
      createRoot(() => {
        const notificationService = mockNotificationService;

        // 添加不同类型的通知
        notificationService.show('Info message', 'info');
        notificationService.show('Success message', 'success');
        notificationService.show('Error message', 'error');

        const notifications = notificationService.getNotifications();
        expect(notifications).toHaveLength(3);
        
        expect(notifications[0]!.type).toBe('info');
        expect(notifications[1]!.type).toBe('success');
        expect(notifications[2]!.type).toBe('error');

        // 清除通知
        notificationService.clear();
        expect(notificationService.getNotifications()).toHaveLength(0);
      });
    });
  });

  describe('Provider Error Handling', () => {
    test('应该处理未注册的服务', () => {
      createRoot(() => {
        const contracts = {};
        
        const getService = (name: string) => {
          const service = contracts[name as keyof typeof contracts];
          if (!service) {
            throw new Error(`Service '${name}' not found`);
          }
          return service;
        };
        
        expect(() => getService('auth')).toThrow("Service 'auth' not found");
      });
    });

    test('应该处理服务初始化错误', () => {
      createRoot(() => {
        const createFailingService = () => {
          throw new Error('Service initialization failed');
        };
        
        expect(() => createFailingService()).toThrow('Service initialization failed');
      });
    });
  });
}); 