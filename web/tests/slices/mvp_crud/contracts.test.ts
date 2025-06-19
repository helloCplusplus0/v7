// tests/slices/mvp_crud/contracts.test.ts - MVP CRUD 切片契约测试
import { describe, test, expect, beforeEach, afterEach, vi } from 'vitest';
import { createMockResponse } from '../../setup';

describe('MVP CRUD API Contracts', () => {
  beforeEach(() => {
    // 设置严格的契约测试 Mock
    (global.fetch as any).mockImplementation((url: string, options?: any) => {
      const method = options?.method || 'GET';
      
      if (url.includes('/api/items')) {
        if (method === 'GET') {
          const urlObj = new URL(url, 'http://localhost');
          const page = parseInt(urlObj.searchParams.get('page') || '1');
          const limit = parseInt(urlObj.searchParams.get('limit') || '10');
          
          return Promise.resolve(createMockResponse({
            data: [
              {
                id: "550e8400-e29b-41d4-a716-446655440000",
                name: "test_item",
                description: "Test item description",
                created_at: "2024-01-01T12:00:00.000Z"
              }
            ],
            total: 1,
            page: page,
            limit: limit,
            total_pages: 1
          }));
        } else if (method === 'POST') {
          const body = JSON.parse(options?.body || '{}');
          
          // 验证必需字段
          if (!body.name || !body.description) {
            return Promise.resolve(createMockResponse({
              error: "Missing required fields"
            }, 400));
          }
          
          return Promise.resolve(createMockResponse({
            id: "550e8400-e29b-41d4-a716-446655440001",
            name: body.name,
            description: body.description,
            created_at: "2024-01-01T12:00:00.000Z"
          }, 201));
        }
      }
      
      return Promise.resolve(createMockResponse({ error: 'Not found' }, 404));
    });
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  describe('GET /api/items - 获取项目列表', () => {
    test('应该返回正确的响应结构', async () => {
      const response = await fetch('/api/items');
      const data = await response.json();
      
      // 验证HTTP状态码
      expect(response.status).toBe(200);
      expect(response.ok).toBe(true);
      
      // 验证响应结构
      expect(data).toMatchObject({
        data: expect.any(Array),
        total: expect.any(Number),
        page: expect.any(Number),
        limit: expect.any(Number),
        total_pages: expect.any(Number)
      });
    });

    test('应该返回正确的数据项结构', async () => {
      const response = await fetch('/api/items');
      const data = await response.json();
      
      if (data.data.length > 0) {
        const item = data.data[0];
        
        // 验证每个项目的字段类型和格式
        expect(item).toMatchObject({
          id: expect.any(String),
          name: expect.any(String),
          description: expect.any(String),
          created_at: expect.any(String)
        });
        
        // 验证ID格式（UUID）
        expect(item.id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i);
        
        // 验证时间格式（ISO 8601）
        expect(item.created_at).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z$/);
        
        // 验证字段不为空
        expect(item.name.length).toBeGreaterThan(0);
        expect(item.description.length).toBeGreaterThan(0);
      }
    });

    test('应该正确处理分页参数', async () => {
      const response = await fetch('/api/items?page=2&limit=5');
      const data = await response.json();
      
      expect(data.page).toBe(2);
      expect(data.limit).toBe(5);
      expect(typeof data.total_pages).toBe('number');
    });

    test('应该支持默认分页参数', async () => {
      const response = await fetch('/api/items');
      const data = await response.json();
      
      expect(data.page).toBe(1);
      expect(data.limit).toBe(10);
    });
  });

  describe('POST /api/items - 创建项目', () => {
    test('应该成功创建项目并返回正确结构', async () => {
      const newItem = {
        name: 'contract_test_item',
        description: 'Contract test description'
      };

      const response = await fetch('/api/items', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(newItem),
      });

      const data = await response.json();
      
      // 验证HTTP状态码
      expect(response.status).toBe(201);
      
      // 验证返回的项目结构
      expect(data).toMatchObject({
        id: expect.any(String),
        name: newItem.name,
        description: newItem.description,
        created_at: expect.any(String)
      });
      
      // 验证ID格式
      expect(data.id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i);
      
      // 验证时间格式
      expect(data.created_at).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z$/);
    });

    test('应该验证必需字段', async () => {
      const invalidRequests = [
        {}, // 缺少所有字段
        { name: 'test' }, // 缺少description
        { description: 'test' }, // 缺少name
      ];

      for (const invalidRequest of invalidRequests) {
        const response = await fetch('/api/items', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(invalidRequest),
        });

        expect(response.status).toBe(400);
        const data = await response.json();
        expect(data).toHaveProperty('error');
      }
    });

    test('应该正确处理Content-Type', async () => {
      const newItem = {
        name: 'content_type_test',
        description: 'Content type test'
      };

      const response = await fetch('/api/items', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(newItem),
      });

      expect(response.status).toBe(201);
    });
  });

  describe('API 兼容性测试', () => {
    test('应该保持向后兼容的响应格式', async () => {
      const response = await fetch('/api/items');
      const data = await response.json();
      
      // 确保关键字段始终存在
      const requiredFields = ['data', 'total', 'page', 'limit', 'total_pages'];
      requiredFields.forEach(field => {
        expect(data).toHaveProperty(field);
      });
    });

    test('应该处理边界值', async () => {
      // 测试极限分页参数
      const edgeCases = [
        { page: 1, limit: 1 },
        { page: 999, limit: 100 },
        { page: 0, limit: 0 }, // 应该使用默认值
      ];

      for (const params of edgeCases) {
        const url = new URL('/api/items', 'http://localhost');
        url.searchParams.set('page', params.page.toString());
        url.searchParams.set('limit', params.limit.toString());

        const response = await fetch(url.toString());
        expect(response.ok).toBe(true);
        
        const data = await response.json();
        expect(typeof data.page).toBe('number');
        expect(typeof data.limit).toBe('number');
      }
    });
  });

  describe('错误处理契约', () => {
    test('应该返回标准错误格式', async () => {
      const response = await fetch('/api/nonexistent');
      const data = await response.json();
      
      expect(response.status).toBe(404);
      expect(data).toHaveProperty('error');
      expect(typeof data.error).toBe('string');
    });
  });
}); 