// shared/api/types.ts - API基础类型定义

export interface ApiResponse<T = any> {
  data: T;
  success: boolean;
  message?: string;
  errors?: string[];
}

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

export interface ApiError extends Error {
  status: number;
  response?: any;
}

export interface RequestConfig {
  timeout?: number;
  retries?: number;
  retryDelay?: number;
  method?: string;
  headers?: HeadersInit;
  body?: BodyInit | null;
}

export interface ApiClientConfig {
  baseUrl: string;
  timeout: number;
  retries: number;
  retryDelay: number;
  headers?: Record<string, string>;
} 