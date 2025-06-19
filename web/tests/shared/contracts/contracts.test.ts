// tests/shared/contracts/contracts.test.ts
import { describe, test, expect, beforeEach } from 'vitest';
import { createRoot } from 'solid-js';
import { AuthContract, NotificationContract, LoginRequest } from '../../../shared/contracts';
import type { User, Notification } from '../../../shared/events/events.types';

// Mock implementations for testing
class MockAuthService implements AuthContract {
  private currentUser: User | null = null;
  private token: string | null = null;

  async login(credentials: LoginRequest): Promise<User> {
    if (credentials.username === 'test' && credentials.password === 'password') {
      const user: User = { 
        id: '1', 
        name: 'Test User', 
        email: 'test@example.com',
        token: 'mock-token'
      };
      this.currentUser = user;
      this.token = 'mock-token';
      return user;
    }
    throw new Error('Invalid credentials');
  }

  async logout(): Promise<void> {
    this.currentUser = null;
    this.token = null;
  }

  getCurrentUser(): User | null {
    return this.currentUser;
  }

  isAuthenticated(): boolean {
    return this.currentUser !== null && this.token !== null;
  }

  getToken(): string | null {
    return this.token;
  }
}

class MockNotificationService implements NotificationContract {
  private notifications: Notification[] = [];
  private nextId = 1;

  show(message: string, type: 'info' | 'error' | 'success' = 'info'): void {
    const notification: Notification = {
      id: this.nextId++,
      message,
      type,
      timestamp: Date.now()
    };
    this.notifications.push(notification);
  }

  clear(): void {
    this.notifications = [];
  }

  getNotifications(): Notification[] {
    return [...this.notifications];
  }
}

describe('Contracts', () => {
  let authService: MockAuthService;
  let notificationService: MockNotificationService;

  beforeEach(() => {
    authService = new MockAuthService();
    notificationService = new MockNotificationService();
  });

  describe('AuthContract', () => {
    test('应该能够成功登录', async () => {
      const credentials: LoginRequest = { username: 'test', password: 'password' };
      const result = await authService.login(credentials);
      
      expect(result).toEqual({
        id: '1',
        name: 'Test User',
        email: 'test@example.com',
        token: 'mock-token'
      });
      
      expect(authService.isAuthenticated()).toBe(true);
      expect(authService.getToken()).toBe('mock-token');
    });

    test('应该在无效凭据时抛出错误', async () => {
      const credentials: LoginRequest = { username: 'invalid', password: 'wrong' };
      await expect(authService.login(credentials)).rejects.toThrow('Invalid credentials');
      
      expect(authService.isAuthenticated()).toBe(false);
      expect(authService.getToken()).toBeNull();
    });

    test('应该能够获取当前用户', async () => {
      const credentials: LoginRequest = { username: 'test', password: 'password' };
      await authService.login(credentials);
      
      const user = authService.getCurrentUser();
      expect(user).toEqual({
        id: '1',
        name: 'Test User',
        email: 'test@example.com',
        token: 'mock-token'
      });
    });

    test('应该在未登录时返回null', () => {
      expect(authService.getCurrentUser()).toBeNull();
      expect(authService.isAuthenticated()).toBe(false);
      expect(authService.getToken()).toBeNull();
    });

    test('应该能够登出', async () => {
      const credentials: LoginRequest = { username: 'test', password: 'password' };
      await authService.login(credentials);
      
      expect(authService.isAuthenticated()).toBe(true);
      
      await authService.logout();
      
      expect(authService.getCurrentUser()).toBeNull();
      expect(authService.isAuthenticated()).toBe(false);
      expect(authService.getToken()).toBeNull();
    });
  });

  describe('NotificationContract', () => {
    test('应该能够显示通知', () => {
      notificationService.show('Test message', 'info');
      
      const notifications = notificationService.getNotifications();
      expect(notifications).toHaveLength(1);
      
      const notification = notifications[0]!;
      expect(notification.message).toBe('Test message');
      expect(notification.type).toBe('info');
      expect(notification.id).toBe(1);
      expect(typeof notification.timestamp).toBe('number');
    });

    test('应该能够显示不同类型的通知', () => {
      notificationService.show('Success!', 'success');
      notificationService.show('Error!', 'error');
      notificationService.show('Info!', 'info');
      
      const notifications = notificationService.getNotifications();
      expect(notifications).toHaveLength(3);
      
      expect(notifications[0]!.type).toBe('success');
      expect(notifications[1]!.type).toBe('error');
      expect(notifications[2]!.type).toBe('info');
    });

    test('应该默认使用info类型', () => {
      notificationService.show('Default message');
      
      const notifications = notificationService.getNotifications();
      expect(notifications[0]!.type).toBe('info');
    });

    test('应该能够清除所有通知', () => {
      notificationService.show('Message 1');
      notificationService.show('Message 2');
      notificationService.show('Message 3');
      
      expect(notificationService.getNotifications()).toHaveLength(3);
      
      notificationService.clear();
      
      expect(notificationService.getNotifications()).toHaveLength(0);
    });

    test('应该为每个通知分配唯一ID', () => {
      notificationService.show('Message 1');
      notificationService.show('Message 2');
      notificationService.show('Message 3');
      
      const notifications = notificationService.getNotifications();
      const ids = notifications.map(n => n.id);
      
      expect(ids).toEqual([1, 2, 3]);
      expect(new Set(ids).size).toBe(3); // 确保所有ID都是唯一的
    });

    test('应该返回通知副本而非原始数组', () => {
      notificationService.show('Test message');
      
      const notifications1 = notificationService.getNotifications();
      const notifications2 = notificationService.getNotifications();
      
      expect(notifications1).not.toBe(notifications2); // 不同的引用
      expect(notifications1).toEqual(notifications2); // 但内容相同
    });
  });
}); 