// tests/shared/api/base.test.ts
import { describe, test, expect, beforeEach, vi } from 'vitest';
import { BaseApiClient, ApiError } from '../../../shared/api/base';

// 创建测试用的API客户端
class TestApiClient extends BaseApiClient {
  public async testGet<T>(endpoint: string) {
    return this.get<T>(endpoint);
  }
  
  public async testPost<T>(endpoint: string, data?: any) {
    return this.post<T>(endpoint, data);
  }
  
  public async testPut<T>(endpoint: string, data?: any) {
    return this.put<T>(endpoint, data);
  }
  
  public async testDelete<T>(endpoint: string) {
    return this.delete<T>(endpoint);
  }
}

// Mock fetch
const mockFetch = vi.fn();
global.fetch = mockFetch;

describe('BaseApiClient', () => {
  let client: TestApiClient;

  beforeEach(() => {
    client = new TestApiClient();
    mockFetch.mockClear();
  });

  describe('基础请求功能', () => {
    test('应该能够发送GET请求', async () => {
      const mockResponse = { id: 1, name: 'test' };
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockResponse),
      });

      const result = await client.testGet('/test');

      expect(mockFetch).toHaveBeenCalledWith(
        '/api/test',
        expect.objectContaining({
          headers: expect.objectContaining({
            'Content-Type': 'application/json',
          }),
        })
      );
      expect(result).toEqual(mockResponse);
    });

    test('应该能够发送POST请求', async () => {
      const mockResponse = { success: true };
      const postData = { name: 'test' };
      
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockResponse),
      });

      const result = await client.testPost('/test', postData);

      expect(mockFetch).toHaveBeenCalledWith(
        '/api/test',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify(postData),
          headers: expect.objectContaining({
            'Content-Type': 'application/json',
          }),
        })
      );
      expect(result).toEqual(mockResponse);
    });

    test('应该能够发送PUT请求', async () => {
      const mockResponse = { updated: true };
      const putData = { name: 'updated' };
      
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockResponse),
      });

      const result = await client.testPut('/test/1', putData);

      expect(mockFetch).toHaveBeenCalledWith(
        '/api/test/1',
        expect.objectContaining({
          method: 'PUT',
          body: JSON.stringify(putData),
        })
      );
      expect(result).toEqual(mockResponse);
    });

    test('应该能够发送DELETE请求', async () => {
      const mockResponse = { deleted: true };
      
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockResponse),
      });

      const result = await client.testDelete('/test/1');

      expect(mockFetch).toHaveBeenCalledWith(
        '/api/test/1',
        expect.objectContaining({
          method: 'DELETE',
        })
      );
      expect(result).toEqual(mockResponse);
    });
  });

  describe('错误处理', () => {
    test('应该处理HTTP错误状态', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 404,
        text: () => Promise.resolve('Not Found'),
      });

      await expect(client.testGet('/not-found')).rejects.toThrow(ApiError);
    });

    test('应该处理网络错误', async () => {
      mockFetch.mockRejectedValueOnce(new TypeError('Network error'));

      // 会触发重试机制
      await expect(client.testGet('/test')).rejects.toThrow(TypeError);
    });
  });

  describe('认证', () => {
    test('应该添加认证头', async () => {
      // Mock localStorage
      const mockLocalStorage = {
        getItem: vi.fn().mockReturnValue('test-token'),
      };
      Object.defineProperty(global, 'localStorage', {
        value: mockLocalStorage,
        writable: true,
      });

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({}),
      });

      await client.testGet('/test');

      expect(mockFetch).toHaveBeenCalledWith(
        '/api/test',
        expect.objectContaining({
          headers: expect.objectContaining({
            'Authorization': 'Bearer test-token',
          }),
        })
      );
    });
  });

  describe('配置', () => {
    test('应该支持自定义配置', () => {
      const customClient = new TestApiClient({
        baseUrl: 'https://api.example.com',
        timeout: 5000,
        retries: 5,
        retryDelay: 2000,
      });

      expect(customClient['baseUrl']).toBe('https://api.example.com');
      expect(customClient['timeout']).toBe(5000);
      expect(customClient['retries']).toBe(5);
      expect(customClient['retryDelay']).toBe(2000);
    });
  });
}); 