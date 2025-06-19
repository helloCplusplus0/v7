// shared/signals/AppSignals.ts - 全局信号定义
import { createSignal } from 'solid-js';
import type { User, Notification, CartItem } from '../events/events.types';

// 用户状态信号
export const [globalUser, setGlobalUser] = createSignal<User | null>(null);

// 主题状态信号
export const [globalTheme, setGlobalTheme] = createSignal<'light' | 'dark'>('light');

// 购物车状态信号
export const [globalCart, setGlobalCart] = createSignal<CartItem[]>([]);

// 通知状态信号
export const [globalNotifications, setGlobalNotifications] = createSignal<Notification[]>([]); 