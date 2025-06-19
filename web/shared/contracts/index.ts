// shared/contracts/index.ts - 契约映射
import type { AuthContract } from './AuthContract';
import type { NotificationContract } from './NotificationContract';

export type { AuthContract, LoginRequest } from './AuthContract';
export type { NotificationContract } from './NotificationContract';

// 契约映射接口
export interface ContractMap {
  auth: AuthContract;
  notification: NotificationContract;
} 