import '@testing-library/jest-dom';
import { beforeAll, afterEach, afterAll, vi } from 'vitest';
import { cleanup } from '@solidjs/testing-library';

// 设置测试环境变量，确保API路径与生产环境一致
process.env.VITE_API_BASE_URL = '/api';

// Mock fetch for tests that don't use MSW
global.fetch = vi.fn();

// 全局测试服务器设置 - 使用简单的mock而不是MSW
const mockServer = {
  listen: vi.fn(),
  close: vi.fn(),
  resetHandlers: vi.fn(),
  use: vi.fn(),
};

// 为了兼容MSW的API，创建rest对象
export const rest = {
  get: (path: string, handler: Function) => ({ path, handler, method: 'GET' }),
  post: (path: string, handler: Function) => ({ path, handler, method: 'POST' }),
  put: (path: string, handler: Function) => ({ path, handler, method: 'PUT' }),
  delete: (path: string, handler: Function) => ({ path, handler, method: 'DELETE' }),
};

// 启动服务器
beforeAll(() => {
  // 设置默认的fetch mock
  (global.fetch as any).mockImplementation((url: string, options?: any) => {
    const method = options?.method || 'GET';
    
    if (url.includes('/api/hello')) {
      if (method === 'GET') {
        return Promise.resolve({
          ok: true,
          status: 200,
          json: () => Promise.resolve({ message: 'Hello fmod!' }),
        });
      } else if (method === 'POST') {
        return Promise.resolve({
          ok: true,
          status: 200,
          json: () => Promise.resolve({ message: 'Hello fmod!' }),
        });
      }
    }
    
    if (url.includes('/api/health')) {
      return Promise.resolve({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ 
          status: 'ok', 
          timestamp: new Date().toISOString() 
        }),
      });
    }
    
    return Promise.resolve({
      ok: false,
      status: 404,
      json: () => Promise.resolve({ error: 'Not found' }),
    });
  });
});

// 每个测试后清理
afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});

// 关闭服务器
afterAll(() => {
  vi.restoreAllMocks();
});

// 全局测试工具函数
export const createMockResponse = (data: any, status = 200) => {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: () => Promise.resolve(data),
    text: () => Promise.resolve(JSON.stringify(data)),
  } as Response;
};

// 测试数据工厂
export const createTestData = {
  helloResponse: () => ({ message: 'Hello fmod!' }),
  errorResponse: (message = 'Test error') => ({ error: message }),
  user: (overrides = {}) => ({
    id: '1',
    name: 'Test User',
    email: 'test@example.com',
    ...overrides,
  }),
};

// 测试辅助函数
export const waitForElement = (selector: string, timeout = 1000) => {
  return new Promise((resolve, reject) => {
    const startTime = Date.now();
    const checkElement = () => {
      const element = document.querySelector(selector);
      if (element) {
        resolve(element);
      } else if (Date.now() - startTime > timeout) {
        reject(new Error(`Element ${selector} not found within ${timeout}ms`));
      } else {
        setTimeout(checkElement, 10);
      }
    };
    checkElement();
  });
};

// 导出server用于兼容性
export const server = mockServer;