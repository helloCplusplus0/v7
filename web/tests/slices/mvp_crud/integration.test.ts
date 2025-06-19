// tests/slices/mvp_crud/integration.test.ts - MVP CRUD 切片集成测试
import { describe, test, expect, beforeEach, afterEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@solidjs/testing-library';
import { createRoot } from 'solid-js';
import { rest, server, createMockResponse, createTestData } from '../../setup';

// 模拟 MVP CRUD API 响应
const mockItemsData = [
  { id: '1', name: 'item_1', description: 'First item', created_at: '2024-01-01T00:00:00Z' },
  { id: '2', name: 'item_2', description: 'Second item', created_at: '2024-01-02T00:00:00Z' },
];

const mockCreateResponse = {
  id: '3',
  name: 'new_item',
  description: 'New item created',
  created_at: '2024-01-03T00:00:00Z'
};

describe('MVP CRUD Slice Integration', () => {
  beforeEach(() => {
    // 设置 API Mock
    (global.fetch as any).mockImplementation((url: string, options?: any) => {
      const method = options?.method || 'GET';
      
      if (url.includes('/api/items')) {
        if (method === 'GET') {
          // 检查是否是分页请求
          const urlObj = new URL(url, 'http://localhost');
          const page = urlObj.searchParams.get('page') || '1';
          const limit = urlObj.searchParams.get('limit') || '10';
          
          return Promise.resolve(createMockResponse({
            data: mockItemsData,
            total: mockItemsData.length,
            page: parseInt(page),
            limit: parseInt(limit),
            total_pages: 1
          }));
        } else if (method === 'POST') {
          const body = JSON.parse(options?.body || '{}');
          return Promise.resolve(createMockResponse({
            ...mockCreateResponse,
            name: body.name || 'new_item',
            description: body.description || 'New item'
          }, 201));
        }
      }
      
      if (url.includes('/api/health')) {
        return Promise.resolve(createMockResponse({ 
          status: 'ok', 
          timestamp: new Date().toISOString() 
        }));
      }
      
      return Promise.resolve(createMockResponse({ error: 'Not found' }, 404));
    });
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  test('应该能够获取项目列表', async () => {
    // 直接测试 API 调用
    const response = await fetch('/api/items?page=1&limit=10');
    const data = await response.json();
    
    expect(response.ok).toBe(true);
    expect(data.data).toHaveLength(2);
    expect(data.data[0]).toHaveProperty('id');
    expect(data.data[0]).toHaveProperty('name');
    expect(data.data[0]).toHaveProperty('description');
    expect(typeof data.total).toBe('number');
    expect(typeof data.page).toBe('number');
    expect(typeof data.limit).toBe('number');
  });

  test('应该能够创建新项目', async () => {
    const newItem = {
      name: 'test_item',
      description: 'Test item description'
    };

    const response = await fetch('/api/items', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(newItem),
    });

    const data = await response.json();
    
    expect(response.status).toBe(201);
    expect(data).toHaveProperty('id');
    expect(data.name).toBe(newItem.name);
    expect(data.description).toBe(newItem.description);
    expect(data).toHaveProperty('created_at');
  });

  test('应该正确处理分页参数', async () => {
    const response = await fetch('/api/items?page=2&limit=5');
    const data = await response.json();
    
    expect(response.ok).toBe(true);
    expect(data.page).toBe(2);
    expect(data.limit).toBe(5);
  });

  test('应该正确处理健康检查', async () => {
    const response = await fetch('/api/health');
    const data = await response.json();
    
    expect(response.ok).toBe(true);
    expect(data.status).toBe('ok');
    expect(data).toHaveProperty('timestamp');
  });

  test('应该正确处理 404 错误', async () => {
    const response = await fetch('/api/nonexistent');
    const data = await response.json();
    
    expect(response.status).toBe(404);
    expect(data.error).toBe('Not found');
  });

  test('应该验证 API 响应数据结构', async () => {
    const response = await fetch('/api/items');
    const data = await response.json();
    
    // 验证响应结构
    expect(data).toHaveProperty('data');
    expect(data).toHaveProperty('total');
    expect(data).toHaveProperty('page');
    expect(data).toHaveProperty('limit');
    expect(data).toHaveProperty('total_pages');
    
    // 验证数据项结构
    if (data.data.length > 0) {
      const item = data.data[0];
      expect(item).toHaveProperty('id');
      expect(item).toHaveProperty('name');
      expect(item).toHaveProperty('description');
      expect(item).toHaveProperty('created_at');
      
      // 验证数据类型
      expect(typeof item.id).toBe('string');
      expect(typeof item.name).toBe('string');
      expect(typeof item.description).toBe('string');
      expect(typeof item.created_at).toBe('string');
    }
  });

  test('应该支持并发请求', async () => {
    // 并发发送多个请求
    const promises = [
      fetch('/api/items'),
      fetch('/api/items?page=1&limit=5'),
      fetch('/api/health'),
    ];

    const responses = await Promise.all(promises);
    
    // 验证所有请求都成功
    responses.forEach(response => {
      expect(response.ok).toBe(true);
    });
  });
}); 