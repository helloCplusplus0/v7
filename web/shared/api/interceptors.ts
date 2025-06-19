// shared/api/interceptors.ts - API拦截器增强
import type { RequestConfig } from './types';

export interface RequestInterceptor {
  onRequest?: (config: RequestConfig) => RequestConfig | Promise<RequestConfig>;
  onRequestError?: (error: any) => any;
}

export interface ResponseInterceptor {
  onResponse?: (response: Response) => Response | Promise<Response>;
  onResponseError?: (error: any) => any;
}

export interface ApiInterceptors {
  request: RequestInterceptor[];
  response: ResponseInterceptor[];
}

export class InterceptorManager {
  private requestInterceptors: RequestInterceptor[] = [];
  private responseInterceptors: ResponseInterceptor[] = [];

  // 添加请求拦截器
  addRequestInterceptor(interceptor: RequestInterceptor): () => void {
    this.requestInterceptors.push(interceptor);
    return () => this.removeRequestInterceptor(interceptor);
  }

  // 添加响应拦截器
  addResponseInterceptor(interceptor: ResponseInterceptor): () => void {
    this.responseInterceptors.push(interceptor);
    return () => this.removeResponseInterceptor(interceptor);
  }

  // 移除请求拦截器
  private removeRequestInterceptor(interceptor: RequestInterceptor): void {
    const index = this.requestInterceptors.indexOf(interceptor);
    if (index > -1) {
      this.requestInterceptors.splice(index, 1);
    }
  }

  // 移除响应拦截器
  private removeResponseInterceptor(interceptor: ResponseInterceptor): void {
    const index = this.responseInterceptors.indexOf(interceptor);
    if (index > -1) {
      this.responseInterceptors.splice(index, 1);
    }
  }

  // 执行请求拦截器
  async executeRequestInterceptors(config: RequestConfig): Promise<RequestConfig> {
    let finalConfig = config;
    
    for (const interceptor of this.requestInterceptors) {
      try {
        if (interceptor.onRequest) {
          finalConfig = await interceptor.onRequest(finalConfig);
        }
      } catch (error) {
        if (interceptor.onRequestError) {
          await interceptor.onRequestError(error);
        }
        throw error;
      }
    }
    
    return finalConfig;
  }

  // 执行响应拦截器
  async executeResponseInterceptors(response: Response): Promise<Response> {
    let finalResponse = response;
    
    for (const interceptor of this.responseInterceptors) {
      try {
        if (interceptor.onResponse) {
          finalResponse = await interceptor.onResponse(finalResponse);
        }
      } catch (error) {
        if (interceptor.onResponseError) {
          await interceptor.onResponseError(error);
        }
        throw error;
      }
    }
    
    return finalResponse;
  }

  // 获取拦截器
  getInterceptors(): ApiInterceptors {
    return {
      request: [...this.requestInterceptors],
      response: [...this.responseInterceptors]
    };
  }

  // 清除所有拦截器
  clearAll(): void {
    this.requestInterceptors = [];
    this.responseInterceptors = [];
  }
}

// 预定义的常用拦截器

// 日志拦截器
export const createLoggingInterceptor = (): RequestInterceptor & ResponseInterceptor => ({
  onRequest: (config) => {
    console.log(`🚀 API Request: ${config.method || 'GET'}`);
    return config;
  },
  onResponse: (response) => {
    console.log(`✅ API Response: ${response.status} ${response.url}`);
    return response;
  },
  onRequestError: (error) => {
    console.error('❌ API Request Error:', error);
  },
  onResponseError: (error) => {
    console.error('❌ API Response Error:', error);
  }
});

// 认证Token刷新拦截器
export const createTokenRefreshInterceptor = (
  refreshTokenFn: () => Promise<string>
): ResponseInterceptor => ({
  onResponseError: async (error) => {
    if (error.status === 401) {
      try {
        const newToken = await refreshTokenFn();
        localStorage.setItem('auth_token', newToken);
        console.log('🔄 Token refreshed successfully');
      } catch (refreshError) {
        console.error('❌ Token refresh failed:', refreshError);
        // 可以在这里触发登出逻辑
      }
    }
  }
});

// 性能监控拦截器
export const createPerformanceInterceptor = (): RequestInterceptor & ResponseInterceptor => {
  const timings = new Map<string, number>();

  return {
    onRequest: (config) => {
      const key = `${config.method || 'GET'}`;
      timings.set(key, Date.now());
      return config;
    },
    onResponse: (response) => {
      const key = response.url;
      const startTime = timings.get(key);
      if (startTime) {
        const duration = Date.now() - startTime;
        console.log(`⏱️ API Performance: ${key} took ${duration}ms`);
        timings.delete(key);
      }
      return response;
    }
  };
}; 