// shared/contracts/AuthContract.ts - 接口定义
import type { User } from '../events/events.types';

export interface LoginRequest {
  username: string;
  password: string;
}

export interface AuthContract {
  getCurrentUser(): User | null;
  isAuthenticated(): boolean;
  getToken(): string | null;
  login(credentials: LoginRequest): Promise<User>;
  logout(): Promise<void>;
} 