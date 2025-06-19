// shared/events/events.types.ts - 事件类型定义

// 基础类型定义
export interface User {
  id: string;
  name: string;
  email: string;
  token?: string;
}

export interface Profile {
  id: string;
  userId: string;
  displayName: string;
  avatar?: string;
  bio?: string;
}

export interface CartItem {
  id: string;
  name: string;
  price: number;
  quantity: number;
}

export interface Notification {
  id: number;
  message: string;
  type: 'info' | 'error' | 'success';
  timestamp: number;
}

// 事件数据类型映射 - 与EventBus.ts保持同步
export interface EventMap {
  'auth:login': { user: User; token: string };
  'auth:logout': {};
  'profile:updated': { userId: string; profile: Profile };
  'notification:show': { message: string; type: 'info' | 'error' | 'success' };
  'cart:item-added': { item: CartItem; total: number };
  // 测试事件
  'test:event': {};
  'test:once': {};
  'test:unsub': {};
}

// 事件处理器类型
export type EventHandler<K extends keyof EventMap> = (data: EventMap[K]) => void;

// 取消订阅函数类型
export type Unsubscribe = () => void; 