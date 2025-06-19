// shared/contracts/NotificationContract.ts - 通知契约接口
import type { Notification } from '../events/events.types';

export interface NotificationContract {
  show(message: string, type: 'info' | 'error' | 'success'): void;
  clear(): void;
  getNotifications(): Notification[];
} 