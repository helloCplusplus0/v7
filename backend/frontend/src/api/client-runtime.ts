// 🎯 FMOD v7 API Client - 运行时生成，100%准确
// 自动生成，请勿手动修改
// 生成时间: 2025-06-18 08:21:43 UTC

import {
  HttpResponse,
  LoginRequest,
  LoginResponse,
  UserSession,
  Item,
  CreateItemRequest,
  UpdateItemRequest,
  ItemsListResponse,
  ListItemsQuery,
  HealthResponse,
  ApiInfo,
  UserEventsResponse,
  PaginationQuery,
  RuntimeStats,
} from '../types/api-runtime';

// =============================================================================
// API错误类
// =============================================================================

export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public traceId?: string
  ) {
    super(message);
    this.name = 'ApiError';
  }

  toString(): string {
    return `ApiError(${this.status}): ${this.code} - ${this.message}`;
  }
}

// =============================================================================
// API客户端配置
// =============================================================================

export interface ApiClientConfig {
  baseUrl?: string;
  timeout?: number;
  headers?: Record<string, string>;
  retries?: number;
  retryDelay?: number;
}

// =============================================================================
// 主API客户端类
// =============================================================================

export class ApiClient {
  private baseUrl: string;
  private timeout: number;
  private headers: Record<string, string>;
  private retries: number;
  private retryDelay: number;

  constructor(config: ApiClientConfig = {}) {
    this.baseUrl = config.baseUrl || 'http://localhost:3000';
    this.timeout = config.timeout || 30000;
    this.retries = config.retries || 3;
    this.retryDelay = config.retryDelay || 1000;
    this.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...config.headers,
    };
  }

  // ---------------------------------------------------------------------------
  // 认证管理
  // ---------------------------------------------------------------------------

  setAuthToken(token: string): void {
    this.headers['Authorization'] = `Bearer ${token}`;
  }

  removeAuthToken(): void {
    delete this.headers['Authorization'];
  }

  getAuthToken(): string | undefined {
    const auth = this.headers['Authorization'];
    return auth?.startsWith('Bearer ') ? auth.substring(7) : undefined;
  }

  // ---------------------------------------------------------------------------
  // 核心请求方法
  // ---------------------------------------------------------------------------

  private async request<T>(
    method: string,
    path: string,
    data?: any,
    queryParams?: Record<string, any>,
    attempt: number = 1
  ): Promise<T> {
    const url = new URL(`${this.baseUrl}${path}`);

    // 添加查询参数
    if (queryParams) {
      Object.entries(queryParams).forEach(([key, value]) => {
        if (value !== undefined && value !== null) {
          url.searchParams.append(key, String(value));
        }
      });
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeout);

    try {
      const response = await fetch(url.toString(), {
        method,
        headers: this.headers,
        body: data ? JSON.stringify(data) : undefined,
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      let result: any;
      const contentType = response.headers.get('content-type');
      
      if (contentType?.includes('application/json')) {
        result = await response.json();
      } else {
        const text = await response.text();
        result = { data: text };
      }

      if (!response.ok) {
        const error = new ApiError(
          response.status,
          result.error?.code || 'HTTP_ERROR',
          result.error?.message || result.message || `HTTP ${response.status}`,
          result.trace_id
        );

        // 重试逻辑（仅针对特定错误）
        if (attempt < this.retries && this.shouldRetry(response.status)) {
          await this.delay(this.retryDelay * attempt);
          return this.request<T>(method, path, data, queryParams, attempt + 1);
        }

        throw error;
      }

      // 如果返回的是HttpResponse格式，提取data字段
      if (result && typeof result === 'object' && 'data' in result) {
        return result.data as T;
      }

      return result as T;
    } catch (error) {
      clearTimeout(timeoutId);
      
      if (error instanceof ApiError) {
        throw error;
      }

      if (error.name === 'AbortError') {
        throw new ApiError(408, 'TIMEOUT', 'Request timeout');
      }

      if (attempt < this.retries) {
        await this.delay(this.retryDelay * attempt);
        return this.request<T>(method, path, data, queryParams, attempt + 1);
      }

      throw new ApiError(0, 'NETWORK_ERROR', 'Network error occurred');
    }
  }

  private shouldRetry(status: number): boolean {
    return status >= 500 || status === 429 || status === 408;
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  // =============================================================================
  // 认证 API
  // =============================================================================

  async login(credentials: LoginRequest): Promise<LoginResponse> {
    const response = await this.request<LoginResponse>('POST', '/api/auth/login', credentials);
    // 自动设置令牌
    if (response.token) {
      this.setAuthToken(response.token);
    }
    return response;
  }

  async validateToken(): Promise<UserSession> {
    return this.request<UserSession>('GET', '/api/auth/validate');
  }

  async logout(): Promise<void> {
    await this.request<void>('POST', '/api/auth/logout');
    this.removeAuthToken();
  }

  // =============================================================================
  // Items CRUD API
  // =============================================================================

  async getItems(query?: ListItemsQuery): Promise<ItemsListResponse> {
    return this.request<ItemsListResponse>('GET', '/api/items', undefined, query);
  }

  async getItem(id: string): Promise<Item> {
    return this.request<Item>('GET', `/api/items/${id}`);
  }

  async createItem(item: CreateItemRequest): Promise<Item> {
    return this.request<Item>('POST', '/api/items', item);
  }

  async updateItem(id: string, updates: UpdateItemRequest): Promise<Item> {
    return this.request<Item>('PUT', `/api/items/${id}`, updates);
  }

  async deleteItem(id: string): Promise<void> {
    return this.request<void>('DELETE', `/api/items/${id}`);
  }

  // =============================================================================
  // 系统 API
  // =============================================================================

  async healthCheck(): Promise<HealthResponse> {
    return this.request<HealthResponse>('GET', '/health');
  }

  async getApiInfo(): Promise<ApiInfo> {
    return this.request<ApiInfo>('GET', '/api/info');
  }

  // =============================================================================
  // 用户事件 API
  // =============================================================================

  async getUserEvents(params?: PaginationQuery): Promise<UserEventsResponse> {
    return this.request<UserEventsResponse>('GET', '/user/events', undefined, params);
  }

  // =============================================================================
  // 运行时统计 API
  // =============================================================================

  async getRuntimeStats(): Promise<RuntimeStats> {
    return this.request<RuntimeStats>('GET', '/api/runtime/data');
  }
}

// =============================================================================
// 默认客户端实例
// =============================================================================

export const apiClient = new ApiClient();

// =============================================================================
// 便利方法导出
// =============================================================================

export const auth = {
  login: (credentials: LoginRequest) => apiClient.login(credentials),
  validate: () => apiClient.validateToken(),
  logout: () => apiClient.logout(),
  setToken: (token: string) => apiClient.setAuthToken(token),
  removeToken: () => apiClient.removeAuthToken(),
};

export const items = {
  list: (query?: ListItemsQuery) => apiClient.getItems(query),
  get: (id: string) => apiClient.getItem(id),
  create: (item: CreateItemRequest) => apiClient.createItem(item),
  update: (id: string, updates: UpdateItemRequest) => apiClient.updateItem(id, updates),
  delete: (id: string) => apiClient.deleteItem(id),
};

export const system = {
  health: () => apiClient.healthCheck(),
  info: () => apiClient.getApiInfo(),
  stats: () => apiClient.getRuntimeStats(),
};

export const userEvents = {
  list: (params?: PaginationQuery) => apiClient.getUserEvents(params),
};

// =============================================================================
// 类型守卫工具
// =============================================================================

export function isApiError(error: any): error is ApiError {
  return error instanceof ApiError;
}

export function isHttpResponse<T>(obj: any): obj is HttpResponse<T> {
  return obj && typeof obj === 'object' && 'status' in obj && 'message' in obj;
}
