// tests/shared/signals/signals.test.ts
import { describe, test, expect, beforeEach } from 'vitest';
import { createUserAccessor, createThemeAccessor, createCartAccessor } from '../../../shared/signals/accessors';
import { 
  globalUser, setGlobalUser,
  globalTheme, setGlobalTheme,
  globalCart, setGlobalCart
} from '../../../shared/signals/AppSignals';

describe('Signals', () => {
  beforeEach(() => {
    // 重置所有信号状态
    setGlobalUser(null);
    setGlobalTheme('light');
    setGlobalCart([]);
  });

  describe('用户访问器', () => {
    test('应该能够获取和设置用户', () => {
      const userAccessor = createUserAccessor();
      const testUser = { id: '1', name: 'Test User', email: 'test@test.com', token: 'token123' };
      
      expect(userAccessor.getUser()).toBeNull();
      expect(userAccessor.isAuthenticated()).toBe(false);
      expect(userAccessor.getUserId()).toBeNull();
      
      userAccessor.setUser(testUser);
      
      expect(userAccessor.getUser()).toEqual(testUser);
      expect(userAccessor.isAuthenticated()).toBe(true);
      expect(userAccessor.getUserId()).toBe('1');
    });

    test('应该正确处理用户登出', () => {
      const userAccessor = createUserAccessor();
      const testUser = { id: '1', name: 'Test User', email: 'test@test.com', token: 'token123' };
      
      userAccessor.setUser(testUser);
      expect(userAccessor.isAuthenticated()).toBe(true);
      
      userAccessor.setUser(null);
      expect(userAccessor.isAuthenticated()).toBe(false);
      expect(userAccessor.getUserId()).toBeNull();
    });
  });

  describe('主题访问器', () => {
    test('应该能够获取和设置主题', () => {
      const themeAccessor = createThemeAccessor();
      
      expect(themeAccessor.getTheme()).toBe('light');
      
      themeAccessor.setTheme('dark');
      expect(themeAccessor.getTheme()).toBe('dark');
    });

    test('应该能够切换主题', () => {
      const themeAccessor = createThemeAccessor();
      
      expect(themeAccessor.getTheme()).toBe('light');
      
      themeAccessor.toggleTheme();
      expect(themeAccessor.getTheme()).toBe('dark');
      
      themeAccessor.toggleTheme();
      expect(themeAccessor.getTheme()).toBe('light');
    });
  });

  describe('购物车访问器', () => {
    test('应该能够添加商品到购物车', () => {
      const cartAccessor = createCartAccessor();
      const item = { id: '1', name: 'Test Item', price: 100, quantity: 1 };
      
      expect(cartAccessor.getCart()).toHaveLength(0);
      
      cartAccessor.addItem(item);
      expect(cartAccessor.getCart()).toHaveLength(1);
      expect(cartAccessor.getCart()[0]).toEqual(item);
    });

    test('应该能够移除商品', () => {
      const cartAccessor = createCartAccessor();
      const item1 = { id: '1', name: 'Item 1', price: 100, quantity: 1 };
      const item2 = { id: '2', name: 'Item 2', price: 200, quantity: 1 };
      
      cartAccessor.addItem(item1);
      cartAccessor.addItem(item2);
      expect(cartAccessor.getCart()).toHaveLength(2);
      
      cartAccessor.removeItem('1');
      expect(cartAccessor.getCart()).toHaveLength(1);
      const remainingItems = cartAccessor.getCart();
      expect(remainingItems[0]?.id).toBe('2');
    });

    test('应该能够清空购物车', () => {
      const cartAccessor = createCartAccessor();
      const item = { id: '1', name: 'Test Item', price: 100, quantity: 1 };
      
      cartAccessor.addItem(item);
      expect(cartAccessor.getCart()).toHaveLength(1);
      
      cartAccessor.clearCart();
      expect(cartAccessor.getCart()).toHaveLength(0);
    });

    test('应该计算购物车总价', () => {
      const cartAccessor = createCartAccessor();
      const item1 = { id: '1', name: 'Item 1', price: 100, quantity: 2 };
      const item2 = { id: '2', name: 'Item 2', price: 200, quantity: 1 };
      
      cartAccessor.addItem(item1);
      cartAccessor.addItem(item2);
      
      expect(cartAccessor.getTotalPrice()).toBe(400); // 100*2 + 200*1
    });
  });

  describe('信号独立性', () => {
    test('不同的访问器应该访问相同的全局状态', () => {
      const userAccessor1 = createUserAccessor();
      const userAccessor2 = createUserAccessor();
      const testUser = { id: '1', name: 'Test User', email: 'test@test.com', token: 'token123' };
      
      userAccessor1.setUser(testUser);
      
      expect(userAccessor2.getUser()).toEqual(testUser);
      expect(userAccessor2.isAuthenticated()).toBe(true);
    });

    test('信号更改应该立即反映到所有访问器', () => {
      const themeAccessor1 = createThemeAccessor();
      const themeAccessor2 = createThemeAccessor();
      
      expect(themeAccessor1.getTheme()).toBe('light');
      expect(themeAccessor2.getTheme()).toBe('light');
      
      themeAccessor1.setTheme('dark');
      
      expect(themeAccessor2.getTheme()).toBe('dark');
    });
  });
}); 