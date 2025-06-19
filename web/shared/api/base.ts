// shared/api/base.ts - 统一 API 基类
import { createUserAccessor } from '../signals/accessors';
import type { RequestConfig, ApiClientConfig } from './types';

export class ApiError extends Error {
  public status: number;
  public data?: any;
  
  constructor(
    status: number,
    message: string,
    data?: any
  ) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.data = data;
  }
}

export abstract class BaseApiClient {
  protected baseUrl = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000';
  protected timeout = 10000;
  protected retries = 3;
  protected retryDelay = 1000;
  
  constructor(config?: Partial<ApiClientConfig>) {
    if (config) {
      this.baseUrl = config.baseUrl || this.baseUrl;
      this.timeout = config.timeout || this.timeout;
      this.retries = config.retries || this.retries;
      this.retryDelay = config.retryDelay || this.retryDelay;
    }
  }
  
  protected async request<T>(
    endpoint: string,
    options: RequestConfig = {}
  ): Promise<T> {
    // 自动添加认证头
    const authToken = this.getAuthToken();
    const headers = {
      'Content-Type': 'application/json',
      ...(authToken && { Authorization: `Bearer ${authToken}` }),
      ...options.headers,
    };
    
    const url = `${this.baseUrl}${endpoint}`;
    const config: RequestConfig = { 
      timeout: this.timeout,
      ...options, 
      headers 
    };
    
    return this.requestWithRetry(url, config);
  }
  
  private async requestWithRetry<T>(
    url: string, 
    config: RequestConfig,
    attempt = 1
  ): Promise<T> {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), config.timeout || this.timeout);
      
      const response = await fetch(url, { 
        ...config, 
        signal: controller.signal 
      });
      
      clearTimeout(timeoutId);
      
      if (!response.ok) {
        const errorData = await response.text();
        throw new ApiError(response.status, errorData);
      }
      
      const jsonResponse = await response.json();
      
      // 处理后端的包装响应格式 {status, data, error}
      if (jsonResponse && typeof jsonResponse === 'object' && 'data' in jsonResponse) {
        // 检查是否有错误
        if (jsonResponse.error) {
          throw new ApiError(jsonResponse.status || 500, jsonResponse.error);
        }
        // 返回解包后的数据
        return jsonResponse.data as T;
      }
      
      // 如果不是包装格式，直接返回
      return jsonResponse;
    } catch (error) {
      // 重试机制
      if (attempt < (config.retries || this.retries) && this.shouldRetry(error)) {
        await this.delay(config.retryDelay || this.retryDelay);
        return this.requestWithRetry(url, config, attempt + 1);
      }
      
      throw error;
    }
  }
  
  private shouldRetry(error: any): boolean {
    // 网络错误或服务器错误（5xx）时重试
    return (
      error.name === 'AbortError' ||
      error.name === 'TypeError' ||
      (error instanceof ApiError && error.status >= 500)
    );
  }
  
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
  
  private getAuthToken(): string | null {
    // 从全局状态获取 token
    const userAccessor = createUserAccessor();
    const user = userAccessor.getUser();
    return user?.token || localStorage.getItem('auth_token');
  }
  
  // 便捷方法
  protected get<T>(endpoint: string, config?: RequestConfig): Promise<T> {
    return this.request<T>(endpoint, { method: 'GET', ...config });
  }
  
    protected post<T>(endpoint: string, data?: any, config?: RequestConfig): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'POST',
      body: data ? JSON.stringify(data) : null,
      ...config
    });
  }

  protected put<T>(endpoint: string, data?: any, config?: RequestConfig): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'PUT',
      body: data ? JSON.stringify(data) : null,
      ...config
    });
  }
  
  protected delete<T>(endpoint: string, config?: RequestConfig): Promise<T> {
    return this.request<T>(endpoint, { method: 'DELETE', ...config });
  }
} 