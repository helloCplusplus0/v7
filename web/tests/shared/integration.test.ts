// tests/shared/integration.test.ts - 四种解耦通信机制集成测试
import { describe, test, expect, beforeEach, afterEach, vi } from 'vitest';
import { createRoot, createSignal } from 'solid-js';
import { eventBus } from '../../shared/events/EventBus';
import { createUserAccessor } from '../../shared/signals/accessors';

describe('Shared Infrastructure Integration', () => {
  beforeEach(() => {
    // 清理事件监听器
    eventBus.removeAllListeners();
    
    // 重置全局状态
    const userAccessor = createUserAccessor();
    userAccessor.setUser(null);
  });

  afterEach(() => {
    eventBus.removeAllListeners();
  });

  test('应该支持事件驱动 + 信号响应式的协作', () => {
    createRoot(() => {
      const userAccessor = createUserAccessor();
      let notificationReceived = '';

      // 监听登录事件
      eventBus.on('auth:login', ({ user }) => {
        notificationReceived = `欢迎回来，${user.name}！`;
      });

      // 模拟登录过程
      const mockUser = { 
        id: '1', 
        name: 'Test User', 
        email: 'test@example.com',
        token: 'test-token' 
      };
      
      // 1. 设置用户状态（信号响应式）
      userAccessor.setUser(mockUser);
      
      // 2. 发布登录事件（事件驱动）
      eventBus.emit('auth:login', { user: mockUser, token: 'test-token' });

      // 验证状态更新
      expect(userAccessor.getUser()).toEqual(mockUser);
      expect(userAccessor.isAuthenticated()).toBe(true);
      expect(notificationReceived).toBe('欢迎回来，Test User！');
    });
  });

  test('应该支持跨切片状态同步', () => {
    createRoot(() => {
      const userAccessor = createUserAccessor();
      const events: string[] = [];

      // 模拟多个切片监听用户状态变化
      eventBus.on('auth:login', () => {
        events.push('profile-updated');
      });

      eventBus.on('auth:login', () => {
        events.push('cart-synced');
      });

      eventBus.on('auth:logout', () => {
        events.push('cache-cleared');
      });

      // 登录流程
      const user = { 
        id: '1', 
        name: 'User', 
        email: 'user@example.com',
        token: 'token' 
      };
      userAccessor.setUser(user);
      eventBus.emit('auth:login', { user, token: 'token' });

      // 登出流程
      userAccessor.setUser(null);
      eventBus.emit('auth:logout', {});

      expect(events).toEqual(['profile-updated', 'cart-synced', 'cache-cleared']);
      expect(userAccessor.isAuthenticated()).toBe(false);
    });
  });

  test('应该正确处理错误隔离', () => {
    createRoot(() => {
      const errors: Error[] = [];
      
      // 监听器1 - 正常
      eventBus.on('test:event', () => {
        // 正常处理
      });

      // 监听器2 - 抛出错误
      eventBus.on('test:event', () => {
        throw new Error('Handler error');
      });

      // 监听器3 - 正常
      eventBus.on('test:event', () => {
        // 正常处理
      });

      // 捕获控制台错误
      const originalConsoleError = console.error;
      console.error = (message: any, ...args: any[]) => {
        // 检查错误消息
        const fullMessage = typeof message === 'string' ? message : String(message);
        if (fullMessage.includes('监听器执行失败') && args.length > 0) {
          const error = args[0];
          if (error instanceof Error && error.message === 'Handler error') {
            errors.push(error);
          }
        }
        // 调用原始的console.error以保持日志输出
        originalConsoleError.call(console, message, ...args);
      };

      // 发布事件
      eventBus.emit('test:event', {});

      // 恢复console.error
      console.error = originalConsoleError;

      // 验证错误被隔离，不影响其他监听器
      expect(errors.length).toBe(1);
    });
  });

  test('应该支持一次性监听器', () => {
    let callCount = 0;
    
    eventBus.once('test:once', () => {
      callCount++;
    });

    // 多次发布同一事件
    eventBus.emit('test:once', {});
    eventBus.emit('test:once', {});
    eventBus.emit('test:once', {});

    // 验证只被调用一次
    expect(callCount).toBe(1);
  });

  test('应该支持取消订阅', () => {
    let callCount = 0;
    
    const unsubscribe = eventBus.on('test:unsub', () => {
      callCount++;
    });

    eventBus.emit('test:unsub', {});
    expect(callCount).toBe(1);

    // 取消订阅
    unsubscribe();
    
    eventBus.emit('test:unsub', {});
    expect(callCount).toBe(1); // 没有增加
  });
}); 