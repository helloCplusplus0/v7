// 🧪 MVP CRUD 完整集成测试 - 简化版本
// 测试核心集成场景，避免复杂的mock设置

import { describe, test, expect, beforeEach, vi } from 'vitest';
import { createRoot } from 'solid-js';
import { createMockItem, createMockItems, createSuccessResponse } from './test-utils';

// 简化的Mock设置
const mockGrpcClient = {
  createItem: vi.fn(),
  getItem: vi.fn(),
  updateItem: vi.fn(),
  deleteItem: vi.fn(),
  listItems: vi.fn(),
  healthCheck: vi.fn(),
  batchDeleteItems: vi.fn()
};

vi.mock('../../../shared/api', () => ({
  grpcClient: mockGrpcClient
}));

vi.mock('../../../shared/events/EventBus', () => ({
  eventBus: {
    emit: vi.fn(),
    on: vi.fn(() => vi.fn()),
    off: vi.fn(),
    removeAllListeners: vi.fn()
  }
}));

describe('MVP CRUD 完整集成测试', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    
    // 设置默认的成功响应
    const mockItems = createMockItems(3);
    mockGrpcClient.listItems.mockResolvedValue(createSuccessResponse({
      items: mockItems,
      total: mockItems.length
    }));
    
    mockGrpcClient.createItem.mockResolvedValue(createSuccessResponse({ item: createMockItem() }));
    mockGrpcClient.getItem.mockResolvedValue(createSuccessResponse({ item: createMockItem() }));
    mockGrpcClient.updateItem.mockResolvedValue(createSuccessResponse({ item: createMockItem() }));
    mockGrpcClient.deleteItem.mockResolvedValue(createSuccessResponse({}));
    mockGrpcClient.healthCheck.mockResolvedValue(createSuccessResponse({ status: 'healthy' }));
    mockGrpcClient.batchDeleteItems.mockResolvedValue(createSuccessResponse({ success: 2, failed: 0, errors: [] }));
  });

  describe('API 集成测试', () => {
    test('应该能够完成基本的API调用', async () => {
      const { CrudApiClient } = await import('../../../slices/mvp_crud/api');
      
      const apiClient = new CrudApiClient();
      
      // 测试列表查询 - 使用正确的参数
      const listResult = await apiClient.listItems(10, 0);
      expect(listResult.items).toHaveLength(3);
      expect(listResult.total).toBe(3);
      
      // 测试创建
      const createResult = await apiClient.createItem({
        name: '测试项目',
        description: '测试描述',
        value: 100
      });
      expect(createResult).toBeDefined();
      expect(createResult.name).toBeDefined();
      
      // 测试获取单个项目
      const getResult = await apiClient.getItem('test-id');
      expect(getResult).toBeDefined();
      expect(getResult.id).toBeDefined();
      
      // 测试更新
      const updateResult = await apiClient.updateItem('test-id', {
        name: '更新后的项目'
      });
      expect(updateResult).toBeDefined();
      expect(updateResult.id).toBeDefined();
      
      // 测试删除
      await apiClient.deleteItem('test-id');
      expect(mockGrpcClient.deleteItem).toHaveBeenCalledWith({ id: 'test-id' });
    });

    test('应该能够处理健康检查', async () => {
      const { CrudApiClient } = await import('../../../slices/mvp_crud/api');
      
      const apiClient = new CrudApiClient();
      const result = await apiClient.healthCheck();
      
      expect(result).toBe(true);
    });

    test('应该能够处理批量操作', async () => {
      const { CrudApiClient } = await import('../../../slices/mvp_crud/api');
      
      const apiClient = new CrudApiClient();
      const result = await apiClient.batchDeleteItems(['id1', 'id2']);
      
      expect(result.success).toBe(2);
      expect(result.failed).toBe(0);
      expect(result.errors).toEqual([]);
    });
  });

  describe('类型验证集成', () => {
    test('API响应应该符合类型定义', async () => {
      const { CrudApiClient } = await import('../../../slices/mvp_crud/api');
      const { isValidItem } = await import('../../../slices/mvp_crud/types');
      
      const apiClient = new CrudApiClient();
      const result = await apiClient.listItems(10, 0);
      
      expect(result.items).toBeDefined();
      result.items.forEach(item => {
        expect(isValidItem(item)).toBe(true);
      });
    });

    test('创建请求应该符合验证规则', async () => {
      const { CrudApiClient } = await import('../../../slices/mvp_crud/api');
      const { isValidCreateRequest } = await import('../../../slices/mvp_crud/types');
      
      const createRequest = {
        name: '测试项目',
        description: '测试描述',
        value: 100
      };
      
      expect(isValidCreateRequest(createRequest)).toBe(true);
      
      const apiClient = new CrudApiClient();
      const result = await apiClient.createItem(createRequest);
      
      expect(result).toBeDefined();
    });
  });

  describe('表单集成测试', () => {
    test('表单应该能够与API协同工作', async () => {
      const { useItemForm } = await import('../../../slices/mvp_crud/hooks');
      const { CrudApiClient } = await import('../../../slices/mvp_crud/api');
      
      createRoot(async () => {
        const form = useItemForm();
        const apiClient = new CrudApiClient();
        
        // 填写表单
        form.updateField('name', '测试项目');
        form.updateField('description', '测试描述');
        form.updateField('value', 100);
        
        // 验证表单
        expect(form.isValid()).toBe(true);
        
        // 提交表单
        const submitHandler = async (data: any) => {
          const result = await apiClient.createItem(data);
          // submit 方法期望返回 void，不需要返回值
        };
        
        const success = await form.submit(submitHandler);
        expect(success).toBe(true);
      });
    });

    test('表单应该处理API错误', async () => {
      const { useItemForm } = await import('../../../slices/mvp_crud/hooks');
      
      // 模拟API错误
      mockGrpcClient.createItem.mockRejectedValue(new Error('API错误'));
      
      createRoot(async () => {
        const form = useItemForm();
        
        form.updateField('name', '测试项目');
        
        const submitHandler = async () => {
          throw new Error('API错误');
        };
        
        const success = await form.submit(submitHandler);
        expect(success).toBe(false);
        expect(form.submitting()).toBe(false);
      });
    });
  });

  describe('错误处理集成', () => {
    test('应该正确处理网络错误', async () => {
      const { CrudApiClient } = await import('../../../slices/mvp_crud/api');
      
      // 模拟网络错误
      mockGrpcClient.listItems.mockRejectedValue(new Error('网络错误'));
      
      const apiClient = new CrudApiClient();
      
      try {
        await apiClient.listItems(10, 0);
        expect(true).toBe(false); // 不应该到达这里
      } catch (error) {
        expect(error).toBeInstanceOf(Error);
        expect((error as Error).message).toContain('网络错误');
      }
    });

    test('应该正确处理验证错误', async () => {
      const { CrudApiClient } = await import('../../../slices/mvp_crud/api');
      
      // 模拟验证错误
      mockGrpcClient.createItem.mockRejectedValue(new Error('验证失败'));
      
      const apiClient = new CrudApiClient();
      
      try {
        await apiClient.createItem({
          name: '', // 无效的名称
          description: '测试描述',
          value: 100
        });
        expect(true).toBe(false); // 不应该到达这里
      } catch (error) {
        expect(error).toBeInstanceOf(Error);
        expect((error as Error).message).toContain('验证失败');
      }
    });
  });

  describe('性能集成测试', () => {
    test('应该能够处理大量数据', async () => {
      const { CrudApiClient } = await import('../../../slices/mvp_crud/api');
      
      // 模拟大量数据
      const largeDataSet = createMockItems(100);
      mockGrpcClient.listItems.mockResolvedValue(createSuccessResponse({
        items: largeDataSet,
        total: largeDataSet.length
      }));
      
      const apiClient = new CrudApiClient();
      const startTime = Date.now();
      
      const result = await apiClient.listItems(100, 0);
      
      const endTime = Date.now();
      const duration = endTime - startTime;
      
      expect(result.items).toHaveLength(100);
      expect(result.total).toBe(100);
      expect(duration).toBeLessThan(1000); // 应该在1秒内完成
    });

    test('应该能够处理并发请求', async () => {
      const { CrudApiClient } = await import('../../../slices/mvp_crud/api');
      
      const apiClient = new CrudApiClient();
      
      // 创建多个并发请求
      const promises = Array.from({ length: 10 }, (_, i) => 
        apiClient.createItem({
          name: `项目${i}`,
          description: `描述${i}`,
          value: i * 10
        })
      );
      
      const results = await Promise.all(promises);
      
      // 所有请求都应该成功
      results.forEach(result => {
        expect(result).toBeDefined();
      });
    });
  });

  describe('边界条件测试', () => {
    test('应该处理空响应', async () => {
      const { CrudApiClient } = await import('../../../slices/mvp_crud/api');
      
      // 模拟空响应
      mockGrpcClient.listItems.mockResolvedValue(createSuccessResponse({
        items: [],
        total: 0
      }));
      
      const apiClient = new CrudApiClient();
      const result = await apiClient.listItems(10, 0);
      
      expect(result.items).toEqual([]);
      expect(result.total).toBe(0);
    });

    test('应该处理特殊字符', async () => {
      const { CrudApiClient } = await import('../../../slices/mvp_crud/api');
      
      const specialItem = createMockItem({
        name: '特殊字符测试 !@#$%^&*()_+-=[]{}|;:,.<>?',
        description: '包含特殊字符的描述 🚀 📝 ✨'
      });
      
      mockGrpcClient.createItem.mockResolvedValue(createSuccessResponse({ item: specialItem }));
      
      const apiClient = new CrudApiClient();
      const result = await apiClient.createItem({
        name: specialItem.name,
        description: specialItem.description,
        value: specialItem.value
      });
      
      expect(result.name).toBe(specialItem.name);
      expect(result.description).toBe(specialItem.description);
    });
  });
}); 