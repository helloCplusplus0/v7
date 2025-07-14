// tests/shared/events/EventBus.test.ts
import { describe, test, expect, beforeEach, vi } from 'vitest';
import { eventBus } from '../../../shared/events/EventBus';
import type { EventMap } from '../../../shared/events/events.types';

describe('EventBus', () => {
  beforeEach(() => {
    // 清理所有监听器
    (eventBus as any).listeners.clear();
  });

  describe('基础功能', () => {
    test('应该能够发布和订阅事件', () => {
      const handler = vi.fn();
      
      eventBus.on('auth:login', handler);
      eventBus.emit('auth:login', { user: { id: '1', name: 'test', email: 'test@test.com' }, token: 'token123' });
      
      expect(handler).toHaveBeenCalledTimes(1);
      expect(handler).toHaveBeenCalledWith({ 
        user: { id: '1', name: 'test', email: 'test@test.com' }, 
        token: 'token123' 
      });
    });

    test('应该能够取消订阅事件', () => {
      const handler = vi.fn();
      
      const unsubscribe = eventBus.on('auth:login', handler);
      unsubscribe();
      
      eventBus.emit('auth:login', { user: { id: '1', name: 'test', email: 'test@test.com' }, token: 'token123' });
      
      expect(handler).not.toHaveBeenCalled();
    });

    test('应该支持一次性监听', () => {
      const handler = vi.fn();
      
      eventBus.once('auth:logout', handler);
      
      eventBus.emit('auth:logout', {});
      eventBus.emit('auth:logout', {});
      
      expect(handler).toHaveBeenCalledTimes(1);
    });

    test('应该支持多个监听器', () => {
      const handler1 = vi.fn();
      const handler2 = vi.fn();
      
      eventBus.on('auth:login', handler1);
      eventBus.on('auth:login', handler2);
      
      eventBus.emit('auth:login', { user: { id: '1', name: 'test', email: 'test@test.com' }, token: 'token123' });
      
      expect(handler1).toHaveBeenCalledTimes(1);
      expect(handler2).toHaveBeenCalledTimes(1);
    });
  });

  describe('错误处理', () => {
    test('应该捕获处理器中的错误', () => {
      const consoleErrorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
      const errorHandler = vi.fn(() => {
        throw new Error('Handler error');
      });
      const normalHandler = vi.fn();
      
      eventBus.on('auth:login', errorHandler);
      eventBus.on('auth:login', normalHandler);
      
      eventBus.emit('auth:login', { user: { id: '1', name: 'test', email: 'test@test.com' }, token: 'token123' });
      
      expect(consoleErrorSpy).toHaveBeenCalledWith(
        '[EventBus] 监听器执行失败 (auth:login):',
        expect.any(Error)
      );
      expect(normalHandler).toHaveBeenCalledTimes(1);
      
      consoleErrorSpy.mockRestore();
    });

    test('应该安全处理不存在的事件', () => {
      expect(() => {
        eventBus.emit('auth:login', { user: { id: '1', name: 'test', email: 'test@test.com' }, token: 'token123' });
      }).not.toThrow();
    });
  });

  describe('移除监听器', () => {
    test('应该能够移除指定的监听器', () => {
      const handler1 = vi.fn();
      const handler2 = vi.fn();
      
      eventBus.on('auth:login', handler1);
      eventBus.on('auth:login', handler2);
      
      eventBus.off('auth:login', handler1);
      
      eventBus.emit('auth:login', { user: { id: '1', name: 'test', email: 'test@test.com' }, token: 'token123' });
      
      expect(handler1).not.toHaveBeenCalled();
      expect(handler2).toHaveBeenCalledTimes(1);
    });

    test('应该能够移除所有监听器', () => {
      const handler1 = vi.fn();
      const handler2 = vi.fn();
      
      eventBus.on('auth:login', handler1);
      eventBus.on('auth:login', handler2);
      
      eventBus.off('auth:login');
      
      eventBus.emit('auth:login', { user: { id: '1', name: 'test', email: 'test@test.com' }, token: 'token123' });
      
      expect(handler1).not.toHaveBeenCalled();
      expect(handler2).not.toHaveBeenCalled();
    });

    test('应该安全处理移除不存在的监听器', () => {
      const handler = vi.fn();
      
      expect(() => {
        eventBus.off('auth:login', handler);
      }).not.toThrow();
    });
  });

  describe('类型安全', () => {
    test('应该确保事件数据类型正确', () => {
      const handler = vi.fn();
      
      eventBus.on('notification:show', handler);
      eventBus.emit('notification:show', { message: 'Test', type: 'info', timestamp: Date.now() });
      
      expect(handler).toHaveBeenCalledWith({ message: 'Test', type: 'info', timestamp: expect.any(Number) });
    });
  });

  describe('性能测试', () => {
    test('应该能够处理大量监听器', () => {
      // 确保测试开始前清理所有监听器
      eventBus.removeAllListeners();
      
      const handlers = Array.from({ length: 100 }, () => vi.fn());
      
      handlers.forEach(handler => {
        eventBus.on('notification:show', handler);
      });
      
      const startTime = performance.now();
      eventBus.emit('notification:show', { message: 'test', type: 'info', timestamp: Date.now() });
      const endTime = performance.now();
      
      expect(endTime - startTime).toBeLessThan(500); // 应该在500ms内完成
      handlers.forEach(handler => {
        expect(handler).toHaveBeenCalledTimes(1);
      });
    });

    test('应该能够处理大量事件发布', () => {
      // 确保测试开始前清理所有监听器
      eventBus.removeAllListeners();
      
      const handler = vi.fn();
      eventBus.on('notification:show', handler);
      
      const startTime = performance.now();
      for (let i = 0; i < 100; i++) {
        eventBus.emit('notification:show', { message: 'test', type: 'info', timestamp: Date.now() });
      }
      const endTime = performance.now();
      
      expect(endTime - startTime).toBeLessThan(500); // 应该在500ms内完成
      expect(handler).toHaveBeenCalledTimes(100);
    });
  });
}); 