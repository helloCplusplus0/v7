// shared/signals/accessors.ts - 访问器模式，避免直接依赖
import { 
  globalUser, setGlobalUser,
  globalTheme, setGlobalTheme,
  globalCart, setGlobalCart,
  globalNotifications, setGlobalNotifications
} from './AppSignals';
import type { CartItem, Notification } from '../events/events.types';

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

// 通知访问器
export const createNotificationAccessor = () => ({
  getNotifications: globalNotifications,
  setNotifications: setGlobalNotifications,
  addNotification: (notification: Notification) => 
    setGlobalNotifications(prev => [...prev, notification]),
  removeNotification: (id: number) => 
    setGlobalNotifications(prev => prev.filter(n => n.id !== id)),
  clearNotifications: () => setGlobalNotifications([]),
  show: (message: string, type: 'success' | 'error' | 'warning' | 'info' = 'info', duration?: number) => {
    const notification: Notification = {
      id: Date.now(),
      message,
      type,
      timestamp: Date.now(),
      duration
    };
    setGlobalNotifications(prev => [...prev, notification]);
    return notification;
  }
}); 